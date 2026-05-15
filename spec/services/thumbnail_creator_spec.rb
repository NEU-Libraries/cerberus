# frozen_string_literal: true

require 'rails_helper'

describe ThumbnailCreator do
  let(:image_path) { '/test/image.jpg' }

  describe 'call' do
    it 'creates a JP2 file and returns its full IIIF URL' do
      allow(Vips::Image).to receive(:new_from_file).and_return(double('Vips::Image', jp2ksave: nil))
      allow(Time).to receive_message_chain(:now, :to_f, :to_s, :gsub!).and_return('123456789')
      allow(Rails.application.config).to receive(:iiif_host).and_return('http://example.com')
      result = ThumbnailCreator.call(path: image_path)
      expect(result).to eq('http://example.com/iiif/3/123456789.jp2')
    end
  end

  describe 'initialize' do
    it 'sets the path' do
      creator = ThumbnailCreator.new(path: image_path)
      expect(creator.instance_variable_get(:@path)).to eq(image_path)
    end
  end
end
