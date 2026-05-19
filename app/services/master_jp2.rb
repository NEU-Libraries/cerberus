# frozen_string_literal: true

class MasterJp2 < ApplicationService
  def initialize(path:)
    @path = path
  end

  def call
    img = Vips::Image.new_from_file(@path)
    uuid = Time.now.to_f.to_s.gsub!('.', '')
    img.jp2ksave("/home/cerberus/images/#{uuid}.jp2")
    "#{Rails.application.config.iiif_host}/iiif/3/#{uuid}.jp2"
  end
end
