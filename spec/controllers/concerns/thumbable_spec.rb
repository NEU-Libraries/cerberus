# frozen_string_literal: true

require 'rails_helper'

describe Thumbable do
  let(:thumbable_class) do
    Class.new do
      include Thumbable

      # atlas_class is the class-level `atlas_resource` declaration in
      # production. It is per-instance here so one host can stand in for each
      # of the three resource types that share the concern.
      attr_accessor :params, :atlas_class

      def initialize(params, atlas_class = AtlasRb::Work)
        @params = params
        @atlas_class = atlas_class
      end
    end
  end

  let(:file) { double('UploadedFile', tempfile: double('Tempfile', path: '/tmp/upload.png')) }
  let(:urls) do
    { thumbnail:    'https://iiif/x.jp2/full/!85,85/0/default.jpg',
      thumbnail_2x: 'https://iiif/x.jp2/full/!170,170/0/default.jpg',
      preview:      'https://iiif/x.jp2/full/500,/0/default.jpg' }
  end

  describe '#apply_thumbnail' do
    it 'no-ops when no file was uploaded (no mint, no Atlas write)' do
      obj = thumbable_class.new({ thumbnail: nil })
      expect(MasterJp2).not_to receive(:call)
      expect(AtlasRb::Work).not_to receive(:set_thumbnails)

      expect(obj.apply_thumbnail('w-1')).to be_nil
    end

    it 'mints the open JP2 from the upload and persists it via set_thumbnails' do
      obj = thumbable_class.new({ thumbnail: file })
      allow(MasterJp2).to receive(:call).with(path: '/tmp/upload.png')
                                        .and_return(MasterJp2::Result.new(open_base: 'BASE', gated_base: 'G'))
      allow(ThumbnailCreator).to receive(:call).with(base: 'BASE').and_return(urls)

      expect(AtlasRb::Work).to receive(:set_thumbnails).with('w-1', **urls)
      obj.apply_thumbnail('w-1')
    end

    # The concern is shared by the Work/Collection/Community edit forms; it must
    # dispatch to the host's declared class, since all three expose
    # set_thumbnails.
    it 'routes to the declared Atlas class' do
      obj = thumbable_class.new({ thumbnail: file }, AtlasRb::Collection)
      allow(MasterJp2).to receive(:call).and_return(MasterJp2::Result.new(open_base: 'BASE', gated_base: 'G'))
      allow(ThumbnailCreator).to receive(:call).with(base: 'BASE').and_return(urls)

      expect(AtlasRb::Collection).to receive(:set_thumbnails).with('c-1', **urls)
      obj.apply_thumbnail('c-1')
    end
  end
end
