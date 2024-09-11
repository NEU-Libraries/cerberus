# frozen_string_literal: true

require 'rails_helper'

describe ThumbnailCreator do
  let(:image_path) { '/test/image.jpg' }

  describe 'call' do
    it 'creates a JP2 file' do
      allow(Vips::Image).to receive(:new_from_file).and_return(double('Vips::Image', jp2ksave: nil))
      allow(Time).to receive_message_chain(:now, :to_f, :to_s, :gsub!).and_return('123456789')
      result = ThumbnailCreator.call(path: image_path)
      expect(result).to eq('123456789')
    end
  end

  describe 'initialize' do
    it 'sets the path' do
      creator = ThumbnailCreator.new(path: image_path)
      expect(creator.instance_variable_get(:@path)).to eq(image_path)
    end
  end
end
