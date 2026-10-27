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

  describe 'writes' do
    let(:admin) { User.new(email: 'admin@example.com', nuid: '000000004', groups: [], role: 'admin') }
    let(:edit_tab) { edit_work_path(work.id, tab: 'darwin-core') }

    # The schema check is XmlValidator's, with its own specs; the live chain is
    # the TDWG smoke. Here it passes, so these exercise the shape rules and the
    # Atlas writes.
    before do
      allow(Kataba).to receive(:fetch_schema).and_return(instance_double(Nokogiri::XML::Schema, validate: []))
    end

    describe 'update' do
      it 'refuses a signed-in user who cannot edit the work' do
        sign_in User.new(email: 'viewer@example.com', nuid: '000000005', role: 'standard', groups: [])

        put :update, params: { id: work.id, dwc_file: fixture_file_upload('dwc-record.xml', 'application/xml') }

        expect(response).to have_http_status(:forbidden)
      end

      context 'as an editor' do
        before { sign_in admin }

        it 'saves a valid record and returns to the Darwin Core pane' do
          put :update, params: { id: work.id, dwc_file: fixture_file_upload('dwc-record.xml', 'application/xml') }

          expect(response).to redirect_to(edit_tab)
          expect(flash[:notice]).to eq(described_class::SAVED)
          expect(AtlasRb::Work.dwc(work.id, 'xml', nuid: '000000004')).to eq(File.read(record_path))
          expect(DarwinCoreRecord.held_by?(AtlasRb::Work.find(work.id, nuid: '000000004'))).to be(true)
        end

        it 'names the upload as the source in the audit history' do
          put :update, params: { id: work.id, dwc_file: fixture_file_upload('dwc-record.xml', 'application/xml') }

          events = AtlasRb::Resource.history(work.id, nuid: '000000004')['events']
          expect(events.map { |event| event.dig('payload', 'origin') }).to include('dwc_upload')
        end

        it 'refuses a malformed file, writes nothing, and lists the error on the pane' do
          put :update, params: { id:       work.id,
                                 dwc_file: fixture_file_upload('dwc-record-broken.xml', 'application/xml') }

          expect(response).to redirect_to(edit_tab)
          expect(flash[:alert]).to eq(described_class::NOT_SAVED)
          expect(flash[:dwc_errors]).to be_present
          expect(AtlasRb::Work.dwc(work.id, 'xml', nuid: '000000004')).to be_nil
        end

        it 'asks for a file when none was chosen' do
          put :update, params: { id: work.id }

          expect(response).to redirect_to(edit_tab)
          expect(flash[:alert]).to eq(described_class::NO_FILE)
        end
      end
    end

    describe 'destroy' do
      before do
        AtlasRb::Resource.put_dwc(work.id, record_path, nuid: '000000004')
        sign_in admin
      end

      it 'withdraws the record and returns to the Darwin Core pane' do
        delete :destroy, params: { id: work.id }

        expect(response).to redirect_to(edit_tab)
        expect(flash[:notice]).to eq(described_class::REMOVED)
        expect(AtlasRb::Work.dwc(work.id, 'xml', nuid: '000000004')).to be_nil
      end
    end
  end
end
