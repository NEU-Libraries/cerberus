class ContentCreationJob
  include MimeHelper
  include ChecksumHelper

  attr_accessor :core_file_pid, :file_path, :file_name, :delete_file, :poster_path, :small_size, :medium_size, :large_size, :permissions
  attr_accessor :core_record, :employee

  def queue_name
    :content_creation
  end

  def initialize(core_file, file_path, file_name, poster_path=nil, small_size=0, medium_size=0, large_size=0, delete_file=true, permissions=nil)
    self.core_file_pid = core_file
    self.file_path     = file_path
    self.file_name     = file_name
    self.delete_file   = delete_file

    self.poster_path = poster_path

    self.small_size    = small_size
    self.medium_size   = medium_size
    self.large_size    = large_size
    self.permissions   = permissions
  end

  def run
    begin
      self.core_record = CoreFile.find(core_file_pid)

      klass = core_record.canonical_class.constantize
      content_object = klass.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
      content_object.save!

      if !poster_path.blank? # Video or Audio posters
        poster_object = ImageMasterFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint), core_record: core_record)

        File.open(poster_path) do |poster_contents|
          poster_object.add_file(poster_contents, 'content', "poster#{File.extname(poster_path)}")
          poster_object.rightsMetadata.content = core_record.rightsMetadata.content
          poster_object.save!
        end

        DerivativeCreator.new(poster_object.pid).generate_derivatives
      end

      # Zip files that need zippin'.  Just drop in other file types.
      if content_object.instance_of? ZipFile
        # Is it literally a zipfile? or did it just fail to be the other types...
        if File.extname(file_path) == ".zip"
          # if file is large, we http kludge it in to avoid loading into memory
          if File.size(file_path) / 1024000 > 500
            large_upload(content_object, file_path, 'content')
            content_object.properties.mime_type = extract_mime_type(file_path)
            content_object.properties.md5_checksum = new_checksum(file_path)
            content_object.save!
          else
            File.open(file_path) do |file_contents|
              content_object.add_file(file_contents, 'content', file_name)
              content_object.save!
            end
          end
        else
          zip_content(content_object)
        end
      else
        # if file is large, we http kludge it in to avoid loading into memory
        if File.size(file_path) / 1024000 > 500
          large_upload(content_object, file_path, 'content')
          content_object.properties.mime_type = extract_mime_type(file_path)
          content_object.properties.md5_checksum = new_checksum(file_path)
          content_object.save!
        else
          File.open(file_path) do |file_contents|
            content_object.add_file(file_contents, 'content', file_name)
            content_object.save!
          end
        end
      end

      # Assign relevant metadata
      content_object.core_record    = core_record
      content_object.title          = file_name
      content_object.identifier     = content_object.pid
      content_object.depositor      = core_record.depositor
      content_object.proxy_uploader = core_record.proxy_uploader
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
      content_object.original_filename = core_record.original_filename

      content_object.canonize
      # content_object.characterize
      # content_object.properties.mime_type = extract_mime_type(file_path)
      # content_object.properties.md5_checksum = new_checksum(file_path)

      content_object.save! ? content_object : false

      # If the file is of type with text, see if we can get solr to do a full text index
      if core_record.canonical_class.in?(['TextFile', 'MswordFile', 'PdfFile'])
        content_object.extract_content
      end

      if (content_object.instance_of? ImageMasterFile)
         ScaledImageCreator.new(small_size, medium_size, large_size, content_object, permissions).create_scaled_images
      end

      # Derivative creator loads into memory, we're skipping for large files
      if File.size(file_path) / 1024000 < 500
        DerivativeCreator.new(content_object.pid).generate_derivatives
      end

      # Derivative creator modifies the core record and these changes are
      # overriden if we save this open copy of the core record without
      # reloading it first
      core_record.reload
      core_record.tag_as_completed
      core_record.save!
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

    def zip_content(content_object)
      begin
        # Create the name for the zipfile.
        # This prevents the zip upload issue in #664
        z = File.basename(Time.now.to_i.to_s, ".*") + ".zip"
        tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
        zipfile_name = tempdir.join(z).to_s

        # Load our content into said zipfile.
        Zip::Archive.open(zipfile_name, Zip::CREATE) do |zipfile|
          zipfile.add_file(file_path)
        end

        # Add zipfile to the ZipFile object
        File.open(zipfile_name) do |f|
          content_object.add_file(f, "content", File.basename(zipfile_name))
          content_object.save!
        end
      ensure
        FileUtils.rm(zipfile_name)
      end
    end
end
