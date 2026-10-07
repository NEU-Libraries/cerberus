# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DerivativeSizeEstimate do
  let(:dir) { Dir.mktmpdir('size-estimate') }
  let(:name) { 'gated-5b1ce000-0000-4000-8000-000000000001.tif' }
  let(:path) { File.join(dir, name) }

  before { allow(Rails.application.config.x.cerberus).to receive(:derivatives_root).and_return(dir) }
  after { FileUtils.rm_rf(dir) }

  def uri(size) = "https://iiif.example/iiif/3/#{name}/full/#{size}/0/default.jpg"

  # Noise compresses like a detailed photograph, so the estimate is non-trivial.
  def write_source(width: 1200, height: 800)
    Vips::Image.gaussnoise(width, height).cast(:uchar).bandjoin([Vips::Image.gaussnoise(width, height).cast(:uchar)] * 2)
               .copy(interpretation: :srgb).tiffsave(path, **IiifImageCreator::TIFF_OPTIONS)
  end

  def expected(scale)
    source_bpp = File.size(path) / (1200 * 800 * described_class::PYRAMID_PIXELS)
    ((1200 * scale).round * (800 * scale).round * source_bpp * described_class::RATIO).round
  end

  it 'scales a pct: rendition by its pixels and the source TIFF density' do
    write_source

    expect(described_class.call(uri: uri('pct:50'))).to eq(expected(0.5))
  end

  it 'fits a !w,h rendition inside its box' do
    write_source

    expect(described_class.call(uri: uri('!300,300'))).to eq(expected(0.25))
  end

  it 'grows with the rendition' do
    write_source

    small, large = %w[pct:33 pct:75].map { |size| described_class.call(uri: uri(size)) }
    expect(large).to be > small
  end

  it 'gives no estimate for an unknown size token' do
    write_source

    expect(described_class.call(uri: uri('300,'))).to be_nil
  end

  it 'gives no estimate when the source TIFF is missing' do
    expect(described_class.call(uri: uri('pct:50'))).to be_nil
  end

  it 'gives no estimate for a URI it cannot parse' do
    expect(described_class.call(uri: 'https://iiif.example/elsewhere.jpg')).to be_nil
  end

  it 'does not cache a miss, so a source that appears later is estimated' do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

    expect(described_class.call(uri: uri('pct:50'))).to be_nil
    write_source
    expect(described_class.call(uri: uri('pct:50'))).to eq(expected(0.5))
  end
end
