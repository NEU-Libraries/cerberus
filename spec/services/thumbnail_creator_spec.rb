# frozen_string_literal: true

require 'rails_helper'

describe ThumbnailCreator do
  let(:base) { 'http://example.com/iiif/3/open-aaa.tif' }

  describe 'call' do
    it 'returns the sized IIIF URLs and the preview size and placeholder' do
      image = IiifImageCreator::Result.new(open_base: base, open_width: 500, open_height: 333, open_placeholder: 'PH')

      expect(ThumbnailCreator.call(image: image)).to eq(
        thumbnail:           "#{base}/full/!85,85/0/default.jpg",
        thumbnail_2x:        "#{base}/full/!170,170/0/default.jpg",
        preview:             "#{base}/full/max/0/default.jpg",
        preview_width:       500,
        preview_height:      333,
        preview_placeholder: 'PH'
      )
    end

    # set_thumbnails compacts the nils away, and Atlas then clears any size it
    # held for the old preview.
    it 'passes nil through when the placeholder did not fit' do
      image = IiifImageCreator::Result.new(open_base: base, open_width: 500, open_height: 333)

      expect(ThumbnailCreator.call(image: image)[:preview_placeholder]).to be_nil
    end
  end
end

# Live against the test Atlas: the values must survive the write and come back
# on the Work read the show page renders.
describe ThumbnailCreator, 'through Atlas' do
  let(:dir) { Dir.mktmpdir('preview') }
  let(:fixture) { ->(name) { Rails.root.join('spec/fixtures/files', name).to_s } }

  before(:all) do
    files = Rails.root.join('spec/fixtures/files')
    @community  = AtlasRb::Community.create(nil, files.join('community-mods.xml').to_s, nuid: '000000004')
    @collection = AtlasRb::Collection.create(@community.id, files.join('collection-mods.xml').to_s, nuid: '000000004')
  end

  before { allow(Rails.application.config.x.cerberus).to receive(:derivatives_root).and_return(dir) }
  after { FileUtils.rm_rf(dir) }

  it 'stores the preview size and placeholder and returns them on the Work read' do
    work = AtlasRb::Work.create(@collection.id, fixture.call('work-mods.xml'), nuid: '000000004')
    image = IiifImageCreator.call(path: fixture.call('beach.jpg'))

    AtlasRb::Resource.set_thumbnails(work.id, **ThumbnailCreator.call(image: image), nuid: '000000004')
    read = AtlasRb::Work.find(work.id, nuid: '000000004')

    expect(read.preview).to eq("#{image.open_base}/full/max/0/default.jpg")
    expect([read.preview_width, read.preview_height]).to eq([image.open_width, image.open_height])
    expect(read.preview_placeholder).to eq(image.open_placeholder)
  end
end
