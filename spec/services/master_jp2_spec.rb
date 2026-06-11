# frozen_string_literal: true

require 'rails_helper'

describe MasterJp2 do
  let(:image_path) { '/test/image.jpg' }

  describe 'call' do
    it 'writes the JP2 to the shared IIIF volume and returns the IIIF base URL' do
      vips_image = double('Vips::Image', jp2ksave: nil)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(vips_image)
      allow(Time).to receive_message_chain(:now, :to_f, :to_s, :gsub!).and_return('123456789')
      allow(Rails.application.config).to receive(:iiif_host).and_return('http://example.com')

      expect(MasterJp2.call(path: image_path)).to eq('http://example.com/iiif/3/123456789.jp2')
      expect(vips_image).to have_received(:jp2ksave).with('/home/cerberus/images/123456789.jp2')
    end
  end

  describe 'call with a PDF source' do
    let(:pdf_path) { Rails.root.join('spec/fixtures/files/example.pdf').to_s }

    it 'passes the poppler dpi option so page 1 rasterizes at 150 dpi' do
      vips_image = double('Vips::Image', jp2ksave: nil)
      allow(Vips::Image).to receive(:new_from_file).with(pdf_path, dpi: 150).and_return(vips_image)
      allow(Time).to receive_message_chain(:now, :to_f, :to_s, :gsub!).and_return('987654321')
      allow(Rails.application.config).to receive(:iiif_host).and_return('http://example.com')

      expect(MasterJp2.call(path: pdf_path)).to eq('http://example.com/iiif/3/987654321.jp2')
      expect(vips_image).to have_received(:jp2ksave).with('/home/cerberus/images/987654321.jp2')
    end

    it 'really loads PDFs through vips/poppler (environment guard for the container image)' do
      img = Vips::Image.new_from_file(pdf_path, dpi: 150)
      expect(img.width).to be_positive
    end
  end

  describe 'initialize' do
    it 'sets the path' do
      expect(MasterJp2.new(path: image_path).instance_variable_get(:@path)).to eq(image_path)
    end
  end
end
