class ContentCreationJob
  include MimeHelper
  include ChecksumHelper
  include SentinelHelper

  attr_accessor :core_file_pid, :file_path, :file_name, :delete_file, :poster_path, :small_size, :medium_size, :large_size
  attr_accessor :core_record, :employee, :sentinel, :caption_path

  def queue_name
    :content_creation
  end

  def initialize(core_file, file_path, file_name, poster_path=nil, caption_path=nil, small_size=0, medium_size=0, large_size=0, delete_file=true)
    self.core_file_pid = core_file
    self.file_path     = file_path
    self.file_name     = file_name
    self.delete_file   = delete_file

    self.poster_path = poster_path
    self.caption_path = caption_path

    self.small_size    = small_size
    self.medium_size   = medium_size
    self.large_size    = large_size
  end

  def run
    # If file_path doesn't exist, or file doesn't exist, don't run
    # and email exception
    if file_path.blank? || !(File.exists?(file_path))
      ExceptionNotifier.notify_exception(Exceptions::MissingFile.new())
      return
    end

    begin
      self.core_record = CoreFile.find(core_file_pid)
      self.sentinel = core_record.parent.sentinel

      klass = core_record.canonical_class.constantize
      content_object = klass.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
      content_object.save!

      if !poster_path.blank? # Video or Audio posters
        poster_object = ImageMasterFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint), core_record: core_record)

        File.open(poster_path) do |poster_contents|
          poster_object.add_file(poster_contents, 'content', "poster#{File.extname(poster_path)}")
          # Poster is a thumbnail, always take core record rightsMetadata
          # no need for sentinel
          poster_object.rightsMetadata.content = core_record.rightsMetadata.content
          poster_object.save!
        end

        DerivativeCreator.new(poster_object.pid).generate_derivatives
      end

      if !caption_path.blank? # Video or Audio captions files
        caption_object = TextFile.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint), core_record: core_record)

        File.open(caption_path) do |caption_contents|
          caption_object.add_file(caption_contents, 'content', "caption#{File.extname(caption_path)}")
          caption_object.rightsMetadata.content = core_record.rightsMetadata.content #apply core_record permissions
          # and sentinel permissions in case they exist
          if sentinel && !sentinel.send(sentinel_class_to_symbol(klass.to_s)).blank?
            # set content object to sentinel value
            # convert klass to string to send to sentinel to get rights
            caption_object.permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["permissions"]
            caption_object.mass_permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["mass_permissions"]
          end
          caption_object.save!
        end
      end

      # Zip files that need zippin'.  Just drop in other file types.
      if content_object.instance_of? ZipFile
        # Is it literally a zipfile? or did it just fail to be the other types...
        if File.extname(file_path) == ".zip"
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
        else
          zip_content(content_object)
        end
      else
        # if file is large, we http kludge it in to avoid loading into memory
        if File.size(file_path) / 1024000 > 50
          large_upload(content_object, file_path, 'content')
          content_object.properties.mime_type = extract_mime_type(file_path, core_record.original_filename)
          content_object.properties.md5_checksum = new_checksum(file_path)
          content_object.properties.file_size = File.size(file_path).to_s
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

      if sentinel && !sentinel.send(sentinel_class_to_symbol(klass.to_s)).blank?
        # set content object to sentinel value
        # convert klass to string to send to sentinel to get rights
        content_object.permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["permissions"]
        content_object.mass_permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["mass_permissions"]
        content_object.save!
      else
        content_object.rightsMetadata.content = core_record.rightsMetadata.content
      end

      content_object.original_filename = core_record.original_filename

      content_object.canonize
      # content_object.characterize
      # content_object.properties.mime_type = extract_mime_type(file_path)
      # content_object.properties.md5_checksum = new_checksum(file_path)

      content_object.properties.mime_type = extract_mime_type(file_path, core_record.original_filename)

      content_object.save! ? content_object : false

      # If the file is of type with text, see if we can get solr to do a full text index
      if core_record.canonical_class.in?(['TextFile', 'MswordFile', 'PdfFile'])
        content_object.extract_content
      end

      if (content_object.instance_of? ImageMasterFile)
         ScaledImageCreator.new(small_size, medium_size, large_size, content_object.pid).create_scaled_images
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

      # Fire off a backgrounded virus check
      Cerberus::Application::Queue.push(VirusCheckJob.new(content_object.fedora_file_path, core_file_pid))

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
      res = ''
      uri = URI("#{ActiveFedora.config.credentials[:url]}/objects/#{content_object.pid}/datastreams/#{dsid}?controlGroup=M&dsLocation=file://#{file_path}")
      Net::HTTP.start(uri.host, uri.port) do |http|
        http.read_timeout = 60000
        request = Net::HTTP::Post.new uri
        request.basic_auth("#{ActiveFedora.config.credentials[:user]}", "#{ActiveFedora.config.credentials[:password]}")
        res = http.request request # Net::HTTPResponse object
      end
      return res
    end

    def zip_content(content_object)
      begin
        # Create the name for the zipfile.
        # This prevents the zip upload issue in #664
        z = File.basename(Time.now.to_f.to_s.gsub!('.','-'), ".*") + ".zip"
        tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
        zipfile_name = tempdir.join(z).to_s

        # Load our content into said zipfile.
        # Zip::File.open(zipfile_name, Zip::File::CREATE) do |zipfile|
        #   zipfile.add(file_name, file_path)
        # end

        `zip -j #{zipfile_name} #{file_path}`
        `printf "@ #{file_path}\n@=#{content_object.original_filename}\n" | #{Cerberus::Application.config.zipnote_path} -w #{zipfile_name}`

        # Add zipfile to the ZipFile object
        # File.open(zipfile_name) do |f|
        #   content_object.add_file(f, "content", File.basename(zipfile_name))
        #   content_object.save!
        # end

        large_upload(content_object, zipfile_name, 'content')
        content_object.save!
      ensure
        FileUtils.rm(zipfile_name)
      end
    end
end
