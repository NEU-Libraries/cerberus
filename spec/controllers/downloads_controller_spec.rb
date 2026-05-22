# frozen_string_literal: true

require 'rails_helper'

describe DownloadsController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: '000000004') }
  let(:work) { AtlasRb::Work.create(collection.id, '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: '000000004') }

  let(:noid) do
    AtlasRb::Blob.create(work.id, '/home/cerberus/web/spec/fixtures/files/image.png', 'image.png', nuid: '000000004')
    AtlasRb::Work.assets(work.id, nuid: '000000004').first.noid
  end

  describe 'show' do
    context 'with public read permission' do
      before do
        allow(AtlasRb::Resource).to receive(:permissions).with(noid, nuid: '000000001').and_return(
          AtlasRb::Mash.new('embargo' => '', 'depositor' => [], 'read' => ['public'], 'edit' => [])
        )
      end

      it 'streams the file with correct headers' do
        blob = AtlasRb::Blob.find(noid, nuid: '000000004')

        get :show, params: { id: noid }

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq(blob.mime_type)
        expect(response.headers['Content-Disposition']).to include('attachment')
        expect(response.headers['Content-Disposition']).to include(blob.filename)
      end
    end

    context 'without read permission' do
      before do
        allow(AtlasRb::Resource).to receive(:permissions).with(noid, nuid: '000000001').and_return(
          AtlasRb::Mash.new('embargo' => '', 'depositor' => [], 'read' => ['private-group'], 'edit' => [])
        )
      end

      it 'returns 403' do
        get :show, params: { id: noid }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
