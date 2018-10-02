class ContentObjectCreationJob
  include MimeHelper
  include ChecksumHelper

  attr_accessor :core_file_pid, :file_path, :permissions, :content_object_pid, :file_name, :mass_permissions
  attr_accessor :core_record, :content_object, :sentinel

  def queue_name
    :content_object_creation
  end

  def initialize(core_file, file_path, content_object, file_name, permissions = nil, mass_permissions = nil)
    self.core_file_pid = core_file
    self.file_path     = file_path
    self.file_name     = file_name
    self.content_object_pid = content_object
    self.mass_permissions = mass_permissions
    self.permissions   = permissions
  end

  def run
    begin
      self.core_record = CoreFile.find(core_file_pid)
      self.content_object = ActiveFedora::Base.find(content_object_pid, cast: true)

      self.sentinel = core_record.parent.sentinel
      klass = core_record.canonical_class.constantize

      # if file is large, we http kludge it in to avoid loading into memory
      if File.size(file_path) / 1024000 > 50
        large_upload(content_object, file_path, 'content')
        content_object.properties.mime_type = extract_mime_type(file_path)
        content_object.properties.md5_checksum = new_checksum(file_path)
        content_object.properties.file_size = File.size(file_path).to_s
        content_object.save!
      else
        File.open(file_path) do |file_contents|
          content_object.add_file(file_contents, 'content', file_name)
          content_object.save!
        end
      end
      content_object.reload

      # Assign relevant metadata
      content_object.core_record    = core_record
      content_object.title          = file_name
      content_object.identifier     = content_object.pid
      content_object.proxy_uploader = core_record.proxy_uploader

      if !permissions.blank? && !mass_permissions.blank?
        content_object.permissions = permissions
        content_object.rightsMetadata.permissions({group: "northeastern:drs:repository:staff"}, "edit") #this is required
        content_object.mass_permissions = mass_permissions
      elsif sentinel && !sentinel.send(sentinel_class_to_symbol(klass.to_s)).blank?
        # set content object to sentinel value
        # convert klass to string to send to sentinel to get rights
        content_object.permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["permissions"]
        content_object.mass_permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["mass_permissions"]
        content_object.save!
      else
        content_object.rightsMetadata.content = core_record.rightsMetadata.content
      end

      # content_object.characterize
      content_object.properties.mime_type = extract_mime_type(file_path)
      content_object.save!

      # If the file is of type with text, see if we can get solr to do a full text index
      # commenting out because we are only useing this for audio/video right now
      # if core_record.canonical_class.in?(['TextFile', 'MswordFile', 'PdfFile'])
      #   content_object.extract_content
      # end

      Rails.cache.delete_matched("/content_objects/#{core_record.pid}*")
      return content_object
    ensure
      if File.exists?(file_path)
        FileUtils.rm(file_path)
      end
    end
  end

  private

    def large_upload(content_object, file_path, dsid)
      url = URI("#{ActiveFedora.config.credentials[:url]}")
      req = Net::HTTP::Post.new("#{ActiveFedora.config.credentials[:url]}/objects/#{content_object.pid}/datastreams/#{dsid}?controlGroup=M&dsLocation=file://#{file_path}")
      req.basic_auth("#{ActiveFedora.config.credentials[:user]}", "#{ActiveFedora.config.credentials[:password]}")
      req.add_field("Content-Type", "#{extract_mime_type(file_path)}")
      req.add_field("Transfer-Encoding", "chunked")
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.read_timeout = 600
        http.request(req)
      }
      return res
    end
end
