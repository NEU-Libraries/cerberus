# frozen_string_literal: true

require 'rails_helper'

describe LoadsController do
  let(:community) { AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml') }
  let(:collection) { AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml') }
  let(:work) { AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml') }
  let(:zip) { fixture_file_upload('/home/cerberus/web/spec/fixtures/files/metadata_existing_files.zip', 'application/zip') }
  let(:zip_s) { fixture_file_upload('/home/cerberus/web/spec/fixtures/files/metadata_existing_file.zip', 'application/zip') }

  describe 'noid test' do
    it 'lets spec set the noid' do
      # not for keeping, just iterating - this lets us hard code pids in the xml zip fixture file
      # and patch them in to test objects for the xml update testing
      AtlasRb::Community.metadata(work['id'], { 'noid' => '123' })
      expect(AtlasRb::Work.find('123')).to be_present
    end
  end

  describe 'create popups' do
    it 'processes the zip file successfully' do
      post :create, params: { file: zip }
      expect(response).to redirect_to(loads_path)
      expect(flash[:notice]).to eq("ZIP file processed successfully.")
      expect(flash[:alert]).to be_nil
    end
  end

  describe 'creates LoadReports and Ingests' do
    it 'creates a LoadReport' do
      expect {
        post :create, params: { file: zip }
      }.to change(LoadReport, :count).by(1)
    end

    it 'creates Ingests' do
      expect {
        post :create, params: { file: zip }
      }.to change(XmlIngest, :count).by(5)
    end
  end

  describe 'updates metadata' do
    it 'updates existing work with new metadata' do
      AtlasRb::Work.metadata(work['id'], { 'noid' => 'neu:test123' })
      found_work = AtlasRb::Work.find('neu:test123')
      expect(found_work).to be_present
      initial_xml_content = AtlasRb::Work.mods(found_work['id'], 'xml')
      expect(initial_xml_content).to be_present
      post :create, params: { file: zip_s }

      updated_work = AtlasRb::Work.find('neu:test123')
      expect(updated_work).to be_present
      updated_xml_content = AtlasRb::Work.mods(updated_work['id'], 'xml')
      expect(updated_xml_content).to be_present

      expect(updated_xml_content).not_to eq(initial_xml_content)
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

    it 'handles zip without manifest' do
      zip_without_manifest = fixture_file_upload('/home/cerberus/web/spec/fixtures/files/zip_without_manifest.zip', 'application/zip')
      post :create, params: { file: zip_without_manifest }
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include('Manifest file not found in ZIP')
    end

    it 'handles missing XML file' do
      zip_with_missing_xml = fixture_file_upload('/home/cerberus/web/spec/fixtures/files/zip_with_missing_xml.zip', 'application/zip')
      post :create, params: { file: zip_with_missing_xml }
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include('file not found in ZIP')
    end

    it 'handles missing PIDs in spreadsheet' do
      zip_with_missing_pids = fixture_file_upload('/home/cerberus/web/spec/fixtures/files/zip_with_missing_pids.zip', 'application/zip')
      post :create, params: { file: zip_with_missing_pids }
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include('Missing PID or filename in row')
    end

    it 'handles Zip::Error' do
      allow(Zip::File).to receive(:open).and_raise(Zip::Error.new("Corrupted zip file"))

      post :create, params: { file: zip }

      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include("Error processing ZIP file: Corrupted zip file")
    end

    it 'handles StandardError during spreadsheet processing' do
      allow(Roo::Spreadsheet).to receive(:open).and_raise(StandardError.new("Invalid spreadsheet format"))

      post :create, params: { file: zip }

      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include("Error processing spreadsheet: Invalid spreadsheet format")
    end

    it 'handles missing headers in spreadsheet' do
      zip_with_missing_headers = fixture_file_upload('/home/cerberus/web/spec/fixtures/files/no_header.zip', 'application/zip')

      post :create, params: { file: zip_with_missing_headers }
      expect(response).to redirect_to(loads_path)
      expect(flash[:alert]).to include("Cannot find header labels")
    end
  end

  describe "index" do
    it "orders LoadReports" do
      oldest_report = LoadReport.create!(status: :completed, created_at: 2.days.ago)
      older_report = LoadReport.create!(status: :completed, created_at: 1.day.ago)
      newer_report = LoadReport.create!(status: :completed, created_at: 1.hour.ago)
      newest_report = LoadReport.create!(status: :completed, created_at: 1.minute.ago)

      get :index

      expect(assigns(:load_reports).to_a).to eq([newest_report, newer_report, older_report, oldest_report])
    end
  end

  it "renders html template" do
    get :index
    expect(response).to render_template("loads/index")
  end
end
