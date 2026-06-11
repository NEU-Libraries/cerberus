# frozen_string_literal: true

require 'rails_helper'
require 'caxlsx'
require 'zip'

# End-to-end create-mode flow, with the manifest authored at runtime via
# caxlsx (the same writer we'll use for spreadsheet export). A create row
# carries a File Name + MODS path and no identifier, so the loader mints a
# new Work seeded with the bundled MODS and hands the content file to the
# ContentCreationJob pipeline. Atlas + XSD validation are stubbed (covered by
# their own suites); the archive is really staged, unpacked, and parsed.
RSpec.describe 'XML loader create-mode flow', type: :request do
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
  let(:tmp_uploads) { Dir.mktmpdir('xml-create-flow') }
  let(:archive_path) { File.join(tmp_uploads, 'create.zip') }

  # Build manifest.xlsx with caxlsx + zip it with a MODS and a content file.
  def build_create_archive(path)
    dir = Dir.mktmpdir('build')
    manifest = File.join(dir, 'manifest.xlsx')
    pkg = Axlsx::Package.new
    pkg.workbook.add_worksheet(name: 'Manifest') do |sheet|
      sheet.add_row ['PIDs', 'MODS XML File Path', 'File Name']
      sheet.add_row ['', 'rec.xml', 'flower.jpg']
    end
    pkg.serialize(manifest)

    Zip::File.open(path, create: true) do |zip|
      zip.add('manifest.xlsx', manifest)
      zip.add('rec.xml', Rails.root.join('spec/fixtures/files/work-mods.xml'))
      zip.add('flower.jpg', Rails.root.join('spec/fixtures/files/flower.jpg'))
    end
  ensure
    FileUtils.rm_rf(dir)
  end

  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    sign_in admin_user
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Work).to receive(:create).and_return(double(id: 'w-created'))
    allow(ContentCreationJob).to receive(:perform_later)
    allow(IiifAssetsJob).to receive(:perform_later)
    build_create_archive(archive_path)
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  it 'mints a Work from the manifest row and hands the content to the ingest pipeline' do
    upload = Rack::Test::UploadedFile.new(archive_path, 'application/zip')
    post '/loaders/xml/loads', params: { load_report: { archive: upload, parent_collection_id: 'neu:root' } }

    lr = LoadReport.last
    expect(lr).to be_previewing

    perform_enqueued_jobs { patch confirm_loader_load_path(xml_loader, lr) }

    lr.reload
    expect(lr.xml_ingests.completed.count).to eq(1)
    expect(lr).to be_completed
    expect(AtlasRb::Work).to have_received(:create).with('neu:root', kind_of(String), idempotency_key: kind_of(String))
    expect(ContentCreationJob).to have_received(:perform_later)
      .with('w-created', a_string_ending_with('flower.jpg'), 'flower.jpg', kind_of(String))
  end
end
