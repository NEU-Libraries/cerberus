# frozen_string_literal: true

require 'rails_helper'

describe Thumbable do
  let(:thumbable_class) do
    Class.new do
      include Thumbable

      attr_accessor :params

      def initialize(params)
        @params = params
      end
    end
  end

  let(:file) { double('UploadedFile', tempfile: double('Tempfile', path: '/tmp/upload.png')) }
  let(:urls) do
    { thumbnail:    'https://iiif/x.jp2/full/!85,85/0/default.jpg',
      thumbnail_2x: 'https://iiif/x.jp2/full/!170,170/0/default.jpg',
      preview:      'https://iiif/x.jp2/full/500,/0/default.jpg' }
  end

  # The Work / Collection / Community edit forms share this concern, and there
  # is nothing type-specific left to assert: Atlas writes thumbnails on
  # /resources/:id/thumbnails whatever the resource is, so the concern takes an
  # id and no type at all.
  describe '#apply_thumbnail' do
    it 'no-ops when no file was uploaded (no mint, no Atlas write)' do
      obj = thumbable_class.new({ thumbnail: nil })
      expect(MasterJp2).not_to receive(:call)
      expect(AtlasRb::Resource).not_to receive(:set_thumbnails)

      expect(obj.apply_thumbnail('w-1')).to be_nil
    end

    it 'mints the open JP2 from the upload and persists it via set_thumbnails' do
      obj = thumbable_class.new({ thumbnail: file })
      allow(MasterJp2).to receive(:call).with(path: '/tmp/upload.png')
                                        .and_return(MasterJp2::Result.new(open_base: 'BASE', gated_base: 'G'))
      allow(ThumbnailCreator).to receive(:call).with(base: 'BASE').and_return(urls)

      expect(AtlasRb::Resource).to receive(:set_thumbnails).with('w-1', **urls)
      obj.apply_thumbnail('w-1')
    end
  end
end
