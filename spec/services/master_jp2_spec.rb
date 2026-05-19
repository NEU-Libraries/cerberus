# frozen_string_literal: true

require 'rails_helper'

describe MasterJp2 do
  let(:image_path) { '/test/image.jpg' }

  describe 'call' do
    it 'writes the JP2 to the shared IIIF volume and returns the IIIF base URL' do
      vips_image = instance_double(Vips::Image)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(vips_image)
      allow(vips_image).to receive(:jp2ksave)
      allow(Time).to receive_message_chain(:now, :to_f, :to_s, :gsub!).and_return('123456789')
      allow(Rails.application.config).to receive(:iiif_host).and_return('http://example.com')

      expect(MasterJp2.call(path: image_path)).to eq('http://example.com/iiif/3/123456789.jp2')
      expect(vips_image).to have_received(:jp2ksave).with('/home/cerberus/images/123456789.jp2')
    end
  end

  describe 'initialize' do
    it 'sets the path' do
      expect(MasterJp2.new(path: image_path).instance_variable_get(:@path)).to eq(image_path)
    end
  end
end
