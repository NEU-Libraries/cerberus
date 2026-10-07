# frozen_string_literal: true

require 'rails_helper'

describe IiifImageCreator do
  let(:image_path) { '/test/image.jpg' }
  let(:tiff) { IiifImageCreator::TIFF_OPTIONS }

  before do
    allow(Rails.application.config).to receive(:iiif_host).and_return('http://example.com')
    allow(SecureRandom).to receive(:uuid).and_return('aaa', 'bbb')
  end

  def source_double(name, **dims)
    double(name, tiffsave: nil, has_alpha?: false, **dims).tap do |img|
      allow(img).to receive(:colourspace).with(:srgb).and_return(img)
    end
  end

  describe 'call' do
    it 'mints a capped open- TIFF and a full-res gated- TIFF on one host, prefix-named' do
      full = source_double('Vips::Image', width: 2000, height: 1000)
      capped = double('Vips::Image capped', tiffsave: nil)
      allow(full).to receive(:resize).with(0.25).and_return(capped)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(full)

      result = IiifImageCreator.call(path: image_path)

      expect(result.open_base).to eq('http://example.com/iiif/3/open-aaa.tif')
      expect(result.gated_base).to eq('http://example.com/iiif/3/gated-bbb.tif')
      expect(capped).to have_received(:tiffsave).with('/home/cerberus/images/open-aaa.tif', **tiff)
      expect(full).to have_received(:tiffsave).with('/home/cerberus/images/gated-bbb.tif', **tiff)
    end

    it 'caps by width (matching the preview 500, request), not longest edge' do
      portrait = source_double('Vips::Image', width: 1000, height: 2000)
      capped = double('Vips::Image capped', tiffsave: nil)
      allow(portrait).to receive(:resize).and_return(capped)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(portrait)

      IiifImageCreator.call(path: image_path)

      # 500 / width(1000) = 0.5 — a longest-edge cap would wrongly use 500/2000 = 0.25.
      expect(portrait).to have_received(:resize).with(0.5)
    end

    it 'does not upscale a source already smaller than the open cap' do
      small = source_double('Vips::Image', width: 300, height: 200)
      allow(small).to receive(:resize).and_return(small)
      allow(Vips::Image).to receive(:new_from_file).with(image_path).and_return(small)

      IiifImageCreator.call(path: image_path)

      expect(small).not_to have_received(:resize)
      expect(small).to have_received(:tiffsave).with('/home/cerberus/images/open-aaa.tif', **tiff)
      expect(small).to have_received(:tiffsave).with('/home/cerberus/images/gated-bbb.tif', **tiff)
    end
  end

  describe 'call with a PDF source' do
    let(:pdf_path) { Rails.root.join('spec/fixtures/files/example.pdf').to_s }

    it 'passes the poppler dpi option so page 1 rasterizes at 150 dpi' do
      full = source_double('Vips::Image', width: 1275, height: 1650)
      capped = double('Vips::Image capped', tiffsave: nil)
      allow(full).to receive(:resize).and_return(capped)
      allow(Vips::Image).to receive(:new_from_file).with(pdf_path, dpi: 150).and_return(full)

      result = IiifImageCreator.call(path: pdf_path)

      expect(result.gated_base).to eq('http://example.com/iiif/3/gated-bbb.tif')
      expect(full).to have_received(:tiffsave).with('/home/cerberus/images/gated-bbb.tif', **tiff)
    end

    it 'really loads PDFs through vips/poppler (environment guard for the container image)' do
      img = Vips::Image.new_from_file(pdf_path, dpi: 150)
      expect(img.width).to be_positive
    end
  end

  # Unstubbed, because what these check is libvips behaviour: the load cache,
  # the pyramid, and the alpha flatten.
  describe 'call, encoding for real' do
    let(:dir) { Dir.mktmpdir('original-tiff') }

    before { allow(Rails.application.config.x.cerberus).to receive(:derivatives_root).and_return(dir) }
    after { FileUtils.rm_rf(dir) }

    def written(base) = Vips::Image.new_from_file(File.join(dir, File.basename(base)))

    # libvips caches a load by path, and a replace or revert restages a new file
    # to the same path as the last one.
    it 'builds from a re-staged file, not the one vips loaded before' do
      source = File.join(dir, 'same-name.png')
      Vips::Image.black(40, 30).write_to_file(source)
      expect(written(IiifImageCreator.call(path: source).gated_base).width).to eq(40)

      Vips::Image.black(64, 20).write_to_file(source)
      expect(written(IiifImageCreator.call(path: source).gated_base).width).to eq(64)
    end

    it 'writes a pyramid, each level half the size of the last' do
      source = File.join(dir, 'source.png')
      Vips::Image.black(2048, 1024, bands: 3).write_to_file(source)

      gated = File.join(dir, File.basename(IiifImageCreator.call(path: source).gated_base))

      expect(Vips::Image.new_from_file(gated).get('n-pages')).to be > 1
      expect(Vips::Image.new_from_file(gated, page: 1).width).to eq(1024)
    end

    it 'flattens transparency, since JPEG has no alpha channel' do
      source = File.join(dir, 'transparent.png')
      Vips::Image.black(64, 64, bands: 4).write_to_file(source)

      expect(written(IiifImageCreator.call(path: source).gated_base).bands).to eq(3)
    end
  end

  describe 'initialize' do
    it 'sets the path' do
      expect(IiifImageCreator.new(path: image_path).instance_variable_get(:@path)).to eq(image_path)
    end
  end
end
