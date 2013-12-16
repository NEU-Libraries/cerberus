require 'RMagick'
include Magick

class ScaledImageCreator

  attr_accessor :small, :med, :large
  attr_accessor :master, :core

  # Pass nil for s/m/l if you do not wish that size of Image derivative
  # to be created. 
  def initialize(s, m, l, mast)
    @small = s 
    @med = m 
    @large = l
    @master = mast
    @core = self.master.core_record 
  end 

  # This takes three duples [x, y] and the ImageMasterFile being used to 
  # generate the derivatives.  Pass nil for a duple if you do not wish that 
  # size to be created.  
  def create_scaled_images
    creation_helper(small, ImageSmallFile, master) if small 
    creation_helper(med, ImageMediumFile, master) if med 
    creation_helper(large, ImageLargeFile, master) if large
  end

  private

    def creation_helper(size, klass, master) 
      x = size[0]
      y = size[1] 

      target = core.content_objects.find { |x| x.instance_of? klass } 
      puts "target is #{target}"

      # If we can't find the derivative, create it. 
      if !target
        puts "creating #{klass}" 
        target = klass.new(pid: Sufia::Noid.namespaceize(Sufia::IdService.mint))
        target.core_record = core 
        target.description = "Derivative for #{core.pid}" 
        target.rightsMetadata.content = master.rightsMetadata.content
        target.identifier = target.pid 
        target.save!
        target.reload
      end

      img = Magick::Image.from_blob(master.content.content) 
      scaled_img = img.resize_to_fill(x, y) 

      target.add_file(scaled_img.to_blob, 'content', master.content.label) 
      target.save!
    end
end