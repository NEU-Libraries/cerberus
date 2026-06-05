# frozen_string_literal: true

require 'rails_helper'

# End-to-end XML-loader flow: LoadsController#create (previewing) →
# #confirm → XmlUnzipJob → XmlIngestJob × N → finalize. The archive is
# really staged and unpacked (the MODS files come out of the fixture zip);
# only the Atlas write and the network-bound XSD validation are stubbed —
# XmlValidator and atlas_rb have their own suites.
RSpec.describe 'XML loader end-to-end flow', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let!(:xml_loader) do
    Loader.create!(slug: 'xml', display_name: 'XML Metadata Loader',
                   group: 'northeastern:drs:repository:loaders:xml',
                   root_collection: 'neu:root', kind: :xml)
  end
  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', role: 'admin', groups: [])
  end
  let(:tmp_uploads) { Dir.mktmpdir('xml-flow') }
  let(:archive) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec/fixtures/files/metadata_existing_files.zip'), 'application/zip'
    )
  end

  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    sign_in admin_user
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Work).to receive(:update)
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  it 'previews on upload, then runs every manifest row to completion on confirm' do
    post '/loaders/xml/loads',
         params: { load_report: { archive: archive, parent_collection_id: 'neu:root' } }

    lr = LoadReport.last
    expect(lr).to be_previewing
    expect(lr.xml_ingests.count).to eq(0)

    perform_enqueued_jobs { patch confirm_loader_load_path(xml_loader, lr) }

    lr.reload
    expect(lr.xml_ingests.count).to eq(5)
    expect(lr.xml_ingests.completed.count).to eq(5)
    expect(lr).to be_completed
    expect(AtlasRb::Work).to have_received(:update).exactly(5).times
  end

  it 'finalizes :failed when a row references a MODS file missing from the archive' do
    # Make the second XML unreadable so its row fails while the rest pass.
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(a_string_ending_with('sample_mods_with_handle_1.xml')).and_return(false)

    post '/loaders/xml/loads',
         params: { load_report: { archive: archive, parent_collection_id: 'neu:root' } }
    perform_enqueued_jobs { patch confirm_loader_load_path(xml_loader, LoadReport.last) }

    lr = LoadReport.last
    expect(lr.xml_ingests.failed.count).to eq(1)
    expect(lr.reload).to be_failed
  end
end
