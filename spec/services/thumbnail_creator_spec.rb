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
