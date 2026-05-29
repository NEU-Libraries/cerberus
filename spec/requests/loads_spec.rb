# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Loads', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:marcom_loader) do
    Loader.create!(
      slug:            'marcom',
      display_name:    'Marketing and Communications',
      group:           'northeastern:drs:repository:loaders:marcom',
      root_collection: 'neu:fix-comm-photos-archive'
    )
  end

  let(:guest_user) do
    User.new(email: 'guest@example.com', password: 'password',
             nuid: '000000001', role: 'guest', groups: [])
  end
  let(:standard_user) do
    User.new(email: 'standard@example.com', password: 'password',
             nuid: '000000005', role: 'standard', groups: [])
  end
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000002', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  let(:marcom_user) do
    User.new(email: 'marcom@example.com', password: 'password',
             nuid: '000000003', role: 'loader',
             groups: ['northeastern:drs:repository:loaders:marcom'])
  end
  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', role: 'admin', groups: [])
  end

  describe 'authorization gate (two-tier: role + group)' do
    context 'as :guest (below loader role tier)' do
      before { sign_in guest_user }

      it 'rejects /loaders/marcom/loads with 403' do
        get '/loaders/marcom/loads'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as :standard (below loader role tier)' do
      before { sign_in standard_user }

      it 'rejects /loaders/marcom/loads with 403' do
        get '/loaders/marcom/loads'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as :privileged staff (passes role gate, fails group gate)' do
      before { sign_in staff_user }

      it 'rejects /loaders/marcom/loads with 403 — primary negative sanity check' do
        get '/loaders/marcom/loads'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as :loader in loaders:marcom group (primary positive case)' do
      before { sign_in marcom_user }

      it 'allows /loaders/marcom/loads' do
        get '/loaders/marcom/loads'
        expect(response).to have_http_status(:ok)
      end
    end

    context 'as :admin (admin short-circuit on the group gate)' do
      before { sign_in admin_user }

      it 'allows /loaders/marcom/loads without per-group membership' do
        get '/loaders/marcom/loads'
        expect(response).to have_http_status(:ok)
      end
    end

    context 'unauthenticated' do
      it 'redirects /loaders/marcom/loads to sign-in' do
        get '/loaders/marcom/loads'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'unknown loader slug' do
    before { sign_in admin_user }

    it 'renders 404 for a missing loader' do
      get '/loaders/nonexistent/loads'
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /loaders/marcom/loads/new' do
    before do
      sign_in marcom_user
      allow(AtlasRb::Collection).to receive(:children)
        .with('neu:fix-comm-photos-archive').and_return(['neu:c1', 'neu:c2'])
      allow(AtlasRb::Collection).to receive(:find).with('neu:c1')
                                                  .and_return(double(id: 'neu:c1', title: 'Campus Life (Photographs)'))
      allow(AtlasRb::Collection).to receive(:find).with('neu:c2')
                                                  .and_return(double(id: 'neu:c2', title: 'Athletics (Photographs)'))
    end

    it 'renders the form with destinations from Atlas' do
      get '/loaders/marcom/loads/new'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Campus Life (Photographs)')
      expect(response.body).to include('Athletics (Photographs)')
    end
  end

  describe 'POST /loaders/marcom/loads' do
    let(:archive) do
      Rack::Test::UploadedFile.new(
        Rails.root.join('spec/fixtures/files/jpgs.zip'), 'application/zip'
      )
    end

    before do
      sign_in marcom_user
      allow(UnzipJob).to receive(:perform_later)
      allow(FileUtils).to receive(:mkdir_p)
      allow(FileUtils).to receive(:cp)
    end

    it 'creates a LoadReport linked to the loader' do
      expect do
        post '/loaders/marcom/loads',
             params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
      end.to change(LoadReport, :count).by(1)

      lr = LoadReport.last
      expect(lr.loader).to eq(marcom_loader)
      expect(lr.parent_collection_id).to eq('neu:c1')
      expect(lr.source_filename).to eq('jpgs.zip')
    end

    it 'enqueues UnzipJob with the new LoadReport id' do
      post '/loaders/marcom/loads',
           params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
      expect(UnzipJob).to have_received(:perform_later).with(LoadReport.last.id)
    end

    it 'redirects to the LoadReport show page' do
      post '/loaders/marcom/loads',
           params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
      expect(response).to redirect_to(loader_load_path(marcom_loader, LoadReport.last))
    end

    it 're-renders :new with 422 when archive is missing' do
      allow(AtlasRb::Collection).to receive(:children).and_return([])
      post '/loaders/marcom/loads', params: { load_report: { parent_collection_id: 'neu:c1' } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(LoadReport.count).to eq(0)
    end
  end

  describe 'GET /loaders/marcom/loads/:id' do
    let!(:load_report) do
      LoadReport.create!(
        loader:               marcom_loader,
        source_filename:      'jpgs.zip',
        parent_collection_id: 'neu:c1',
        status:               :processing
      )
    end

    before { sign_in marcom_user }

    it 'renders the dashboard' do
      get "/loaders/marcom/loads/#{load_report.id}"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('jpgs.zip')
      expect(response.body).to include('Processing')
    end

    # Regression: the report body lives in a turbo-frame, so its
    # descendant links (per-row "Work", the loader subtitle) must break
    # out to a full-page visit — otherwise Turbo looks for the
    # load_report frame in the linked page, fails to find it, and renders
    # "content missing". target="_top" on the frame is what does that.
    it 'gives the turbo-frame target="_top" so descendant links escape the frame' do
      get "/loaders/marcom/loads/#{load_report.id}"
      # Single turbo-frame on the page, so asserting both attributes are
      # present (order-independently) pins the fix without coupling to the
      # tag helper's attribute ordering.
      expect(response.body).to include('id="load_report"')
      expect(response.body).to include('target="_top"')
    end

    it 'returns 404 for a LoadReport that belongs to a different loader' do
      other_loader = Loader.create!(slug: 'other', display_name: 'Other',
                                    group: 'g', root_collection: 'c')
      other_report = LoadReport.create!(loader:               other_loader,
                                        source_filename:      'x.zip',
                                        parent_collection_id: 'c')
      get "/loaders/marcom/loads/#{other_report.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  # Live-progress affordances: while the background batch is still
  # running the show page must NOT show the terminal "no images" copy
  # (the bug — a freshly-created :pending report flashed it), and the
  # frame must be flagged non-terminal with a poll url so the load-poll
  # Stimulus controller self-refreshes it. Once the report is terminal
  # the copy is correct and the frame is flagged terminal so polling stops.
  describe 'GET /loaders/marcom/loads/:id — live progress affordances' do
    before { sign_in marcom_user }

    %i[pending processing].each do |status|
      context "while the report is #{status} with no ingests yet" do
        let!(:load_report) do
          LoadReport.create!(loader:               marcom_loader,
                             source_filename:      'jpgs.zip',
                             parent_collection_id: 'neu:c1',
                             status:               status)
        end

        it 'shows the in-progress state, not the terminal "no images" copy' do
          get "/loaders/marcom/loads/#{load_report.id}"
          expect(response.body).to include('Extraction in progress')
          expect(response.body).not_to include('No images ingested')
        end

        it 'marks the frame non-terminal and hands the poller the report url' do
          get "/loaders/marcom/loads/#{load_report.id}"
          expect(response.body).to include('id="load_report"')
          expect(response.body).to include('data-controller="load-poll"')
          expect(response.body).to include('data-load-poll-terminal-value="false"')
          expect(response.body).to include(
            %(data-load-poll-url-value="#{loader_load_path(marcom_loader, load_report)}")
          )
        end
      end
    end

    context 'when the report has finished with no ingests' do
      let!(:load_report) do
        LoadReport.create!(loader:               marcom_loader,
                           source_filename:      'empty.zip',
                           parent_collection_id: 'neu:c1',
                           status:               :completed)
      end

      it 'shows the terminal "no images" copy, not the in-progress state' do
        get "/loaders/marcom/loads/#{load_report.id}"
        expect(response.body).to include('No images ingested')
        expect(response.body).not_to include('Extraction in progress')
      end

      it 'marks the frame terminal so the poller stops' do
        get "/loaders/marcom/loads/#{load_report.id}"
        expect(response.body).to include('id="load_report"')
        expect(response.body).to include('data-load-poll-terminal-value="true"')
      end
    end

    context 'while processing with some ingests already finished' do
      let!(:load_report) do
        LoadReport.create!(loader:               marcom_loader,
                           source_filename:      'jpgs.zip',
                           parent_collection_id: 'neu:c1',
                           status:               :processing)
      end

      before do
        create(:iptc_ingest, load_report: load_report, status: :completed)
        create(:iptc_ingest, load_report: load_report, status: :pending)
        create(:iptc_ingest, load_report: load_report, status: :processing)
      end

      it 'renders the determinate progress meter with the processed/total count' do
        get "/loaders/marcom/loads/#{load_report.id}"
        expect(response.body).to include('load-report-progress')
        expect(response.body).to include('of 3')
        expect(response.body).to include('aria-valuenow="1"')
        expect(response.body).to include('aria-valuemax="3"')
      end
    end

    context 'when a terminal report has ingests' do
      let!(:load_report) do
        LoadReport.create!(loader:               marcom_loader,
                           source_filename:      'jpgs.zip',
                           parent_collection_id: 'neu:c1',
                           status:               :completed)
      end

      before { create(:iptc_ingest, load_report: load_report, status: :completed) }

      it 'does not render the in-progress meter' do
        get "/loaders/marcom/loads/#{load_report.id}"
        expect(response.body).not_to include('load-report-progress')
      end
    end
  end
end
