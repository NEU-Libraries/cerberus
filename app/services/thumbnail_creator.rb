# frozen_string_literal: true

class ThumbnailCreator < ApplicationService
  def initialize(path:)
    @path = path
  end

  def call
    create_jp2
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
