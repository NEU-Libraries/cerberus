# frozen_string_literal: true

require 'rails_helper'

describe MasterJp2 do
  let(:image_path) { '/test/image.jpg' }

  before { allow(Rails.application.config).to receive(:iiif_host).and_return('http://example.com') }

  describe 'call' do
    it 'mints a capped open JP2 and a full-res gated JP2, returning both bases' do
      full = double('Vips::Image', width: 2000, height: 1000, jp2ksave: nil)
      capped = double('Vips::Image capped', jp2ksave: nil)
      allow(full).to receive(:resize).with(0.25).and_return(capped)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(full)
      allow(SecureRandom).to receive(:uuid).and_return('open-id', 'gated-id')

      result = MasterJp2.call(path: image_path)

      expect(result.open_base).to eq('http://example.com/iiif/3/open-id.jp2')
      expect(result.gated_base).to eq('http://example.com/iiif/3/gated-id.jp2')
      expect(capped).to have_received(:jp2ksave).with('/home/cerberus/images/open-id.jp2')
      expect(full).to have_received(:jp2ksave).with('/home/cerberus/images/gated-id.jp2')
    end

    it 'caps by width (matching the preview 500, request), not longest edge' do
      portrait = double('Vips::Image', width: 1000, height: 2000, jp2ksave: nil)
      capped = double('Vips::Image capped', jp2ksave: nil)
      allow(portrait).to receive(:resize).and_return(capped)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(portrait)
      allow(SecureRandom).to receive(:uuid).and_return('open-id', 'gated-id')

      MasterJp2.call(path: image_path)

      # 500 / width(1000) = 0.5 — a longest-edge cap would wrongly use 500/2000 = 0.25.
      expect(portrait).to have_received(:resize).with(0.5)
    end

    it 'does not upscale a source already smaller than the open cap' do
      small = double('Vips::Image', width: 300, height: 200, jp2ksave: nil)
      allow(small).to receive(:resize).and_return(small)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(small)
      allow(SecureRandom).to receive(:uuid).and_return('open-id', 'gated-id')

      MasterJp2.call(path: image_path)

      expect(small).not_to have_received(:resize)
      expect(small).to have_received(:jp2ksave).with('/home/cerberus/images/open-id.jp2')
      expect(small).to have_received(:jp2ksave).with('/home/cerberus/images/gated-id.jp2')
    end
  end

  describe 'call with a PDF source' do
    let(:pdf_path) { Rails.root.join('spec/fixtures/files/example.pdf').to_s }

    it 'passes the poppler dpi option so page 1 rasterizes at 150 dpi' do
      full = double('Vips::Image', width: 1275, height: 1650, jp2ksave: nil)
      capped = double('Vips::Image capped', jp2ksave: nil)
      allow(full).to receive(:resize).and_return(capped)
      allow(Vips::Image).to receive(:new_from_file).with(pdf_path, dpi: 150).and_return(full)
      allow(SecureRandom).to receive(:uuid).and_return('open-id', 'gated-id')

      result = MasterJp2.call(path: pdf_path)

      expect(result.gated_base).to eq('http://example.com/iiif/3/gated-id.jp2')
      expect(full).to have_received(:jp2ksave).with('/home/cerberus/images/gated-id.jp2')
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
