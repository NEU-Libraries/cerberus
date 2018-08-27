require 'RMagick'
include Magick
include SentinelHelper
include MimeHelper
include ChecksumHelper

class ScaledImageCreator

  attr_accessor :small, :med, :large
  attr_accessor :master, :core

  # Size instance vars should be scale factors, e.g. .25 for a derivative
  # 25% the size of the original
  # Pass nil for s/m/l if you do not wish that size of Image derivative
  def initialize(s, m, l, master_pid)
    @small = s
    @med = m
    @large = l
    @master = ActiveFedora::Base.find(master_pid, cast: true)
    @core = CoreFile.find(self.master.core_record.pid)
  end

  def create_scaled_images
    if valid_dimensions?
      creation_helper(small, ImageSmallFile, master) if small
      creation_helper(med, ImageMediumFile, master) if med
      creation_helper(large, ImageLargeFile, master) if large
    end
  end

  private

    def valid_dimensions?
      valid = true

      if !small.zero? && !med.zero?
        if small > med
          valid = false
        end
      elsif !small.zero? && !large.zero?
        if small > large
          valid = false
        end
      end

      if !med.zero? && !large.zero?
        if med > large
          valid = false
        end
      end

      if !large.zero?
        if large > 1.0
          valid = false
        end
      end

      return valid
    end

    def creation_helper(size, klass, master)
      if size > 0
        target = core.content_objects.find { |x| x.instance_of? klass }
        sentinel = core.parent.sentinel

        # If we can't find the derivative, create it.
        if !target
          target = klass.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
          target.description = "Derivative for #{core.pid}"
          target.rightsMetadata.content = core.rightsMetadata.content
          target.identifier = target.pid
          target.core_record = CoreFile.find(core.pid)
          target.save!
          target.reload

          if sentinel && !sentinel.send(sentinel_class_to_symbol(klass.to_s)).blank?
            # set content object to sentinel value
            # convert klass to string to send to sentinel to get rights
            target.permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["permissions"]
            target.mass_permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["mass_permissions"]
            target.save!
          end
        end

        img = Magick::Image.from_blob(master.content.content).first
        img.format = "JPEG"
        img.interlace = Magick::PlaneInterlace
        img.resize!(size)

        fname = master.original_filename
        fname = "#{fname.chomp(File.extname(fname))}.jpg"

        # target.add_file(scaled_img.to_blob, 'content', fname)

        file_name = Time.now.to_f.to_s.gsub!('.','-') + "-resize.jpg"
        tempdir = Pathname.new("#{Rails.application.config.tmp_path}/")
        file_path = tempdir.join(file_name).to_s

        # write img to tmp dir
        img.write(file_path)

        target.original_filename = fname
        target.save!

        large_upload(target, file_path, 'content')

        target.properties.mime_type = extract_mime_type(file_path)
        target.properties.md5_checksum = new_checksum(file_path)
        target.properties.file_size = File.size(file_path).to_s
        target.save!
      end
    ensure
      img && img.destroy!
      if !file_path.blank? && File.file?(file_path)
        FileUtils.rm(file_path)
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
