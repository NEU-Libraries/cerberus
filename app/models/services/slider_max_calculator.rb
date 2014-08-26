# This service object is used by the CoreFilesController to compute the maximum
# size allowable for small/medium/large objects.
require 'RMagick'
include Magick

class SliderMaxCalculator

  def initialize(file)
    @file = file
  end

  def self.compute(tmp_path)
    img = Magick::Image.ping(tmp_path)

    width  = img[0].columns
    height = img[0].rows

    return width > height ? width : height
  end
end
