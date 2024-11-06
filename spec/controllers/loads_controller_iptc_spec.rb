# frozen_string_literal: true

require 'rails_helper'

describe LoadsController do
  let(:iptc_zip) { fixture_file_upload('/home/cerberus/web/spec/fixtures/files/jpgs_nested.zip', 'application/zip') }
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:iptc_zip_s) { fixture_file_upload('/home/cerberus/web/spec/fixtures/files/nested_singular.zip', 'application/zip') }


  before do
    allow(LoadsController).to receive(:use_iptc_processing?).and_return(true)
    allow(ProcessIptcJob).to receive(:default_collection_id).and_return(collection['id'])
  end

  describe '#show' do
    let(:load_report) { LoadReport.create!(status: :completed) }

    it 'assigns the requested load report' do
      get :show, params: { id: load_report.id }
      expect(assigns(:load_report)).to eq(load_report)
    end
  end

  it 'creates a new work with the proper metadata' do
    post :create, params: { file: iptc_zip_s }

    expect(response).to redirect_to(loads_path)
    expect(flash[:notice]).to eq('Upload processed successfully.')
    ingest = IptcIngest.last
    expect(ingest).to be_present
    # Slightly worried about the below expect (May need a wait/loop on it)
    expect(ingest.ingest.status).to eq('completed')
    children = AtlasRb::Collection.children(collection['id'])
    expect(children.count).to eq(1)
    expect(AtlasRb::Work.mods(children.first)).to include("Bouve Dean's Seminar Series")
  end

  describe 'creates LoadReport and Ingests' do
    it 'creates a LoadReport' do
      expect {
        post :create, params: { file: iptc_zip }
      }.to change(LoadReport, :count).by(1)
    end

    it 'creates Ingests' do
      expect {
        post :create, params: { file: iptc_zip }
      }.to change(Ingest, :count).by(3)
    end
  end

  describe 'error handling' do
    it 'handles missing file' do
      post :create
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to eq('No file uploaded. Please select a ZIP file.')
    end

    it 'handles non-zip file' do
      non_zip = fixture_file_upload('/home/cerberus/web/spec/fixtures/files/spongebob.png', 'text/plain')
      post :create, params: { file: non_zip }
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include('Invalid file type')
    end

    it 'handles a zip with no images' do
      zip = fixture_file_upload('/home/cerberus/web/spec/fixtures/files/metadata_existing_file.zip', 'application/zip')
      post :create, params: { file: zip }
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include('No valid images found in the ZIP file.')
    end

    it 'handles a insufficient metadata image' do
      zip = fixture_file_upload('/home/cerberus/web/spec/fixtures/files/nested_reg_image.zip', 'application/zip')
      post :create, params: { file: zip }
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include('Error extracting IPTC from')
    end

    it 'handles Zip::Error during processing' do
      allow(Zip::File).to receive(:open).and_raise(Zip::Error.new("Corrupted zip file"))
      post :create, params: { file: iptc_zip }
      expect(flash[:alert]).to include("Error processing ZIP file: Corrupted zip file")
    end

    it 'handles Error during process_images' do
      allow(IptcIngest).to receive(:create_from_image_binary)
                             .and_raise(StandardError.new("Failed to create ingest"))
      post :create, params: { file: iptc_zip }
      expect(flash[:alert]).to include("Failed to create ingest")
    end

    it 'handles Error during extract_raw_iptc' do
      allow(MiniExiftool).to receive(:new)
                               .and_raise(StandardError.new("Failed to read IPTC data"))
      post :create, params: { file: iptc_zip }
      expect(flash[:alert]).to include("Failed to read IPTC data")
    end
  end




end
