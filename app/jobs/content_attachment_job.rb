class ContentAttachmentJob
  include MimeHelper
  include ChecksumHelper

  attr_accessor :core_file_pid, :file_path, :delete_file, :permissions, :content_object_pid, :file_name
  attr_accessor :core_record

  def queue_name
    :content_attachment
  end

  def initialize(core_file, file_path, content_object, file_name, delete_file=true, permissions=nil)
    self.core_file_pid = core_file
    self.file_path     = file_path
    self.delete_file   = delete_file
    self.file_name     = file_name
    self.content_object_pid = content_object

    self.permissions   = permissions
  end

  def run
    begin
      self.core_record = CoreFile.find(core_file_pid)
      klass = core_record.canonical_class.constantize
      if klass == AudioFile
        klass = AudioMasterFile
      elsif klass == VideoFile
        klass = VideoMasterFile
      end
      content_object = klass.find(content_object_pid)

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

      # Assign relevant metadata
      content_object.core_record    = core_record
      content_object.title          = file_name
      content_object.identifier     = content_object.pid
      content_object.depositor      = core_record.depositor
      content_object.proxy_uploader = core_record.proxy_uploader
      puts "permissions are #{permissions}"
      if !permissions.nil? && permissions["#{content_object.klass}"]
          perms = permissions["#{content_object.klass}"]
          perms.each do |perm, vals|
            vals.each do |group|
              this_class = Object.const_get("#{content_object.klass}")
              content_object.rightsMetadata.permissions({group: group}, "#{perm}")
            end
          end
      else
        content_object.rightsMetadata.content = core_record.rightsMetadata.content
      end
      content_object.original_filename = file_path

      # content_object.characterize
      content_object.properties.mime_type = extract_mime_type(file_path)
      content_object.properties.md5_checksum = new_checksum(file_path)

      content_object.save! ? content_object : false

      # If the file is of type with text, see if we can get solr to do a full text index
      # commenting out because we are only useing this for audio/video right now
      # if core_record.canonical_class.in?(['TextFile', 'MswordFile', 'PdfFile'])
      #   content_object.extract_content
      # end

      # reload just to be safe
      core_record.reload
      core_record.tag_as_completed
      core_record.save!
      Rails.cache.delete_matched("/content_objects/#{core_record.pid}*")
      return content_object
    ensure
      if delete_file
        if File.exists?(file_path)
          FileUtils.rm(file_path)
        end
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
          http.request(req)
      }
      return res
    end
end
