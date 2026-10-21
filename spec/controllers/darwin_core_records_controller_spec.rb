# frozen_string_literal: true

require 'rails_helper'

describe DarwinCoreRecordsController do
  let(:record_path) { Rails.root.join('spec/fixtures/files/dwc-record.xml').to_s }

  before(:all) do
    @community  = AtlasRb::Community.create(nil, Rails.root.join('spec/fixtures/files/community-mods.xml').to_s,
                                            nuid: '000000004')
    @collection = AtlasRb::Collection.create(@community.id,
                                             Rails.root.join('spec/fixtures/files/collection-mods.xml').to_s,
                                             nuid: '000000004')
  end

  let(:work) do
    created = AtlasRb::Work.create(@collection.id, Rails.root.join('spec/fixtures/files/work-mods.xml').to_s,
                                   nuid: '000000004')
    AtlasRb::Work.complete(created.id, nuid: '000000004')
    AtlasRb::Work.find(created.id, nuid: '000000004')
  end

  def make_public!
    publicize_ancestry!(community: @community, collection: @collection)
    AtlasRb::Resource.set_permissions(work.id, { 'read' => ['public'] }, nuid: '000000004')
  end

  describe 'show' do
    context 'when the work holds a record' do
      before { AtlasRb::Resource.put_dwc(work.id, record_path, nuid: '000000004') }

      it 'downloads the stored XML byte for byte' do
        make_public!

        get :show, params: { id: work.id }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('application/xml')
        expect(response.headers['Content-Disposition']).to include('attachment', "#{work.id}-darwin-core.xml")
        expect(response.body).to eq(File.read(record_path))
      end

      # Set outright, not left to inheritance: another example may already have
      # made the shared collection public, and a new Work inherits its read list.
      it 'refuses a guest the work is not public to' do
        AtlasRb::Resource.set_permissions(work.id, { 'read' => [Permissions::STAFF_EDIT_GROUP] }, nuid: '000000004')

        get :show, params: { id: work.id }

        expect(response).to have_http_status(:forbidden)
      end

      it '404s a guest while the deposit is unfinished' do
        make_public!
        in_progress = AtlasRb::Work.find(work.id, nuid: '000000004')
        in_progress['in_progress'] = true
        allow(AtlasRb::Work).to receive(:find).with(work.id).and_return(in_progress)

        get :show, params: { id: work.id }

        expect(response).to have_http_status(:not_found)
      end
    end

    it '404s a work that holds no record' do
      make_public!

      get :show, params: { id: work.id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
