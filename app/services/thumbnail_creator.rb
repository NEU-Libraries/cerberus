# frozen_string_literal: true

class ThumbnailCreator < ApplicationService
  def initialize(path:)
    @path = path
  end

  def call
    uuid = create_jp2
    base = "#{Rails.application.config.iiif_host}/iiif/3/#{uuid}.jp2"
    {
      'thumbnail'    => "#{base}/full/!85,85/0/default.jpg",
      'thumbnail_2x' => "#{base}/full/!170,170/0/default.jpg",
      'preview'      => "#{base}/full/500,/0/default.jpg"
    }
  end

  private

    def create_jp2
      img = Vips::Image.new_from_file(@path)
      # convert to jp2 and write to shared volume with iiif container
      uuid = Time.now.to_f.to_s.gsub!('.', '')
      img.jp2ksave("/home/cerberus/images/#{uuid}.jp2")
      uuid
    end
end
