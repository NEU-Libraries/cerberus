# frozen_string_literal: true

require 'rails_helper'

# End-to-end multipage-loader flow: LoadsController#create (previewing) →
# preview render → #confirm → MultipageUnzipJob (group + scaffold) →
# MultipageItemJob × items (mint) → MultipageIngestJob × pages → finalize →
# CompleteWorkJob. Archives are really zipped (committed fixtures for the
# real-bytes single-item path, built on the fly for multi-item cases),
# staged, and unpacked; only the Atlas writes and the network-bound XSD
# validation are stubbed.
RSpec.describe 'Multipage loader end-to-end flow', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let!(:multipage_loader) do
    Loader.create!(slug: 'postcards', display_name: 'Multipage Loader',
                   group: 'northeastern:drs:repository:loaders:postcards',
                   root_collection: 'neu:root', kind: :multipage)
  end
  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', role: 'admin', groups: [])
  end
  let(:tmp_uploads) { Dir.mktmpdir('multipage-flow') }

  def fixture_archive(path)
    Rack::Test::UploadedFile.new(path, 'application/zip')
  end

  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    sign_in admin_user
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Resource).to receive(:preview).and_return('<dl>rendered</dl>')
    allow(AtlasRb::Resource).to receive(:find).with('neu:root').and_return(double(klass: 'Collection'))
    allow(AtlasRb::Work).to receive(:create).and_return(double(id: 'w-1'), double(id: 'w-2'))
    allow(AtlasRb::Work).to receive(:complete)
    allow(AtlasRb::Work).to receive(:find).and_return(double(thumbnail: 'http://iiif.example/t.jpg'))
    # A fresh FileSet id per create call, for any page count.
    allow(AtlasRb::FileSet).to receive(:create) { double(id: "fs-#{SecureRandom.hex(4)}") }
    allow(AtlasRb::FileSet).to receive(:update)
    allow(AtlasRb::FileSet).to receive(:set_iiif_service)
    allow(MasterJp2).to receive(:call).and_return('http://iiif.example/iiif/3/p.jp2')
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  def upload(archive_path)
    post '/loaders/postcards/loads',
         params: { load_report: { archive: fixture_archive(archive_path), parent_collection_id: 'neu:root' } }
    LoadReport.last
  end

  describe 'a single-item archive (committed fixture, real bytes)' do
    let(:archive_path) { zip_multipage_fixture('multipage') }

    it 'previews one item, builds its Work with positioned FileSets, and completes it once' do
      # Two positioned pages on the single Work, so completion verifies clean.
      allow(AtlasRb::Work).to receive(:file_sets).and_return(
        [{ 'noid' => 'fs-1', 'position' => 1, 'assets' => [{ 'noid' => 'b-1' }] },
         { 'noid' => 'fs-2', 'position' => 2, 'assets' => [{ 'noid' => 'b-2' }] }]
      )

      lr = upload(archive_path)
      expect(lr).to be_previewing
      expect(lr.multipage_ingests.count).to eq(0)

      get loader_load_path(multipage_loader, lr)
      expect(response.body).to include('bdr_43889.tif').and include('bdr_43890.tif')
      expect(response.body).to include('Confirm').and include('1 item')

      perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, lr) }

      lr.reload
      expect(lr).to be_completed
      expect(lr.multipage_ingests.completed.count).to eq(2)
      expect(lr.multipage_ingests.order(:sequence).pluck(:item_index, :sequence, :work_pid))
        .to eq([[0, 1, 'w-1'], [0, 2, 'w-1']])

      expect(AtlasRb::Work).to have_received(:create).once
      expect(AtlasRb::FileSet).to have_received(:create).with('w-1', 'image', position: 1, idempotency_key: kind_of(String))
      expect(AtlasRb::FileSet).to have_received(:create).with('w-1', 'image', position: 2, idempotency_key: kind_of(String))
      expect(AtlasRb::Work).to have_received(:complete).with('w-1').once
    end
  end

  describe 'a multi-item archive (built)' do
    let(:archive_path) do
      build_multipage_archive([
                                multipage_item(mods: 'a.mods.xml', pages: %w[a1.tif a2.tif], title: 'Item A'),
                                multipage_item(mods: 'b.mods.xml', pages: %w[b1.tif], title: 'Item B')
                              ])
    end

    it 'mints a Work per item and completes each clean Work' do
      # w-1 (Item A) lists 2 positioned pages; w-2 (Item B) lists 1.
      allow(AtlasRb::Work).to receive(:file_sets).with('w-1').and_return(
        [{ 'noid' => 'a1', 'position' => 1, 'assets' => [{ 'noid' => 'x' }] },
         { 'noid' => 'a2', 'position' => 2, 'assets' => [{ 'noid' => 'y' }] }]
      )
      allow(AtlasRb::Work).to receive(:file_sets).with('w-2').and_return(
        [{ 'noid' => 'b1', 'position' => 1, 'assets' => [{ 'noid' => 'z' }] }]
      )

      lr = upload(archive_path)
      get loader_load_path(multipage_loader, lr)
      expect(response.body).to include('2 items')

      perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, lr) }

      lr.reload
      expect(lr).to be_completed
      expect(lr.multipage_ingests.completed.count).to eq(3)
      expect(lr.multipage_ingests.distinct.pluck(:work_pid)).to match_array(%w[w-1 w-2])

      expect(AtlasRb::Work).to have_received(:create).twice
      expect(AtlasRb::Work).to have_received(:complete).with('w-1').once
      expect(AtlasRb::Work).to have_received(:complete).with('w-2').once
    end
  end

  describe 'skip bad, ingest valid' do
    # Item B's MODS file is absent — invalid — while item A is whole.
    let(:archive_path) do
      build_multipage_archive(
        [
          multipage_item(mods: 'a.mods.xml', pages: %w[a1.tif a2.tif], title: 'Item A'),
          multipage_item(mods: 'b.mods.xml', pages: %w[b1.tif], title: 'Item B')
        ],
        omit_files: ['b.mods.xml']
      )
    end

    it 'ingests and completes the good item and reports the bad one as failed' do
      allow(AtlasRb::Work).to receive(:file_sets).with('w-1').and_return(
        [{ 'noid' => 'a1', 'position' => 1, 'assets' => [{ 'noid' => 'x' }] },
         { 'noid' => 'a2', 'position' => 2, 'assets' => [{ 'noid' => 'y' }] }]
      )

      lr = upload(archive_path)
      perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, lr) }

      lr.reload
      expect(lr).to be_failed # the report is failed because one item failed…
      expect(lr.multipage_ingests.completed.count).to eq(2) # …but item A's pages completed
      failed = lr.multipage_ingests.failed.sole
      expect(failed.item_index).to eq(1)
      expect(failed.error_message).to include("MODS XML file 'b.mods.xml' was not found")

      expect(AtlasRb::Work).to have_received(:create).once
      expect(AtlasRb::Work).to have_received(:complete).with('w-1').once
    end
  end

  describe 'an archive with no valid item' do
    let(:archive_path) do
      build_multipage_archive([multipage_item(mods: 'a.mods.xml', pages: %w[a1.tif], title: 'Item A')],
                              omit_files: ['a.mods.xml'])
    end

    it 'blocks the preview, and a forced confirm mints nothing' do
      lr = upload(archive_path)
      get loader_load_path(multipage_loader, lr)
      expect(response.body).not_to include('Confirm &amp; run')
      expect(response.body).to include('No item in this spreadsheet is valid')

      perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, lr) }

      expect(lr.reload).to be_failed
      expect(AtlasRb::Work).not_to have_received(:create)
      expect(AtlasRb::Work).not_to have_received(:complete)
    end
  end

  describe 'when a page fails to attach' do
    let(:archive_path) { zip_multipage_fixture('multipage') }

    it 'never completes the Work' do
      allow(AtlasRb::FileSet).to receive(:update).and_raise(Faraday::ConnectionFailed.new('atlas down'))
      # Atlas agrees the pages never landed, so the resumed-execution verify
      # guard won't treat the attach as already done.
      allow(AtlasRb::Work).to receive(:file_sets).and_return(
        [{ 'noid' => 'fs-1', 'position' => 1, 'assets' => [] },
         { 'noid' => 'fs-2', 'position' => 2, 'assets' => [] }]
      )

      lr = upload(archive_path)
      perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, lr) }

      lr.reload
      expect(lr).to be_failed
      expect(lr.multipage_ingests.failed.count).to eq(2)
      expect(AtlasRb::Work).not_to have_received(:complete)
    end
  end
end
