require 'RMagick'
include Magick

class ScaledImageCreator

  attr_accessor :small, :med, :large
  attr_accessor :master, :core

  # Size instance vars should be scale factors, e.g. .25 for a derivative 
  # 25% the size of the original 
  # Pass nil for s/m/l if you do not wish that size of Image derivative
  def initialize(s, m, l, mast)
    @small = s 
    @med = m 
    @large = l
    @master = mast
    @core = self.master.core_record 
  end 
 
  def create_scaled_images
    creation_helper(small, ImageSmallFile, master) if small 
    creation_helper(med, ImageMediumFile, master) if med 
    creation_helper(large, ImageLargeFile, master) if large
  end

  private

    def creation_helper(size, klass, master)
      target = core.content_objects.find { |x| x.instance_of? klass } 

      # If we can't find the derivative, create it. 
      if !target
        target = klass.new(pid: Sufia::Noid.namespaceize(Sufia::IdService.mint)) 
        target.description = "Derivative for #{core.pid}" 
        target.rightsMetadata.content = master.rightsMetadata.content
        target.identifier = target.pid
        target.core_record = NuCoreFile.find(core.pid)  
        target.save!
        target.reload
      end

      img = Magick::Image.from_blob(master.content.content).first 
      scaled_img = img.resize(size)  

      target.add_file(scaled_img.to_blob, 'content', master.content.label) 
      target.save!
    end
end