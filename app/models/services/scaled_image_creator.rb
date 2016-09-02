require 'RMagick'
include Magick
include SentinelHelper

class ScaledImageCreator

  attr_accessor :small, :med, :large
  attr_accessor :master, :core, :permissions

  # Size instance vars should be scale factors, e.g. .25 for a derivative
  # 25% the size of the original
  # Pass nil for s/m/l if you do not wish that size of Image derivative
  def initialize(s, m, l, master_pid, permissions=nil)
    @small = s
    @med = m
    @large = l
    @master = ActiveFedora::Base.find(master_pid, cast: true)
    @core = CoreFile.find(self.master.core_record.pid)
    @permissions = permissions
  end

  def create_scaled_images
    if valid_dimensions?
      creation_helper(small, ImageSmallFile, master, permissions) if small
      creation_helper(med, ImageMediumFile, master, permissions) if med
      creation_helper(large, ImageLargeFile, master, permissions) if large
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

    def creation_helper(size, klass, master, permissions=nil)
      if size > 0
        target = core.content_objects.find { |x| x.instance_of? klass }
        sentinel = core.parent.sentinel

        # If we can't find the derivative, create it.
        if !target
          target = klass.new(pid: Cerberus::Noid.namespaceize(Cerberus::IdService.mint))
          target.description = "Derivative for #{core.pid}"
          if !permissions.nil? && permissions["#{target.klass}"]
              perms = permissions["#{target.klass}"]
              perms.each do |perm, vals|
                vals.each do |group|
                  this_class = Object.const_get("#{target.klass}")
                  target.rightsMetadata.permissions({group: group}, "#{perm}")
                end
              end
          elsif sentinel && !sentinel.send(sentinel_class_to_symbol(klass.to_s)).blank?
            # set content object to sentinel value
            # convert klass to string to send to sentinel to get rights
            target.permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["permissions"]
            target.mass_permissions = sentinel.send(sentinel_class_to_symbol(klass.to_s))["mass_permissions"]
            target.save!
          else
            target.rightsMetadata.content = core.rightsMetadata.content
          end
          target.identifier = target.pid
          target.core_record = CoreFile.find(core.pid)
          target.save!
          target.reload
        end

        img = Magick::Image.from_blob(master.content.content).first
        img.format = "JPEG"
        img.interlace = Magick::PlaneInterlace
        scaled_img = img.resize(size)

        fname = master.original_filename
        fname = "#{fname.chomp(File.extname(fname))}.jpg"

        target.add_file(scaled_img.to_blob, 'content', fname)
        target.original_filename = fname
        target.save!
      end
    end
end
