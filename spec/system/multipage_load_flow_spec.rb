# frozen_string_literal: true

require 'rails_helper'

# End-to-end multipage-loader flow: LoadsController#create (previewing) →
# preview render → #confirm → MultipageUnzipJob → MultipageIngestJob × N →
# finalize → CompleteWorkJob. The archive is really zipped from the
# unwrapped fixture dir, staged, and unpacked; only the Atlas writes and
# the network-bound XSD validation are stubbed.
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

  def fixture_archive(dir)
    Rack::Test::UploadedFile.new(zip_multipage_fixture(dir), 'application/zip')
  end

  def positioned_listing
    [
      { 'noid' => 'fs-1', 'type' => 'image', 'position' => 1, 'assets' => [{ 'noid' => 'b-1' }] },
      { 'noid' => 'fs-2', 'type' => 'image', 'position' => 2, 'assets' => [{ 'noid' => 'b-2' }] }
    ]
  end

  before do
    @orig = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    sign_in admin_user
    allow(XmlValidator).to receive(:call).and_return([])
    allow(AtlasRb::Resource).to receive(:preview).and_return('<dl>rendered</dl>')
    allow(AtlasRb::Work).to receive(:create).and_return(double(id: 'w-new'))
    allow(AtlasRb::Work).to receive(:file_sets).and_return(positioned_listing)
    allow(AtlasRb::Work).to receive(:complete)
    # An existing thumbnail makes IiifAssetsJob a no-op — JP2 generation
    # has its own suite.
    allow(AtlasRb::Work).to receive(:find).and_return(double(thumbnail: 'http://iiif.example/t.jpg'))
    allow(AtlasRb::FileSet).to receive(:create).and_return(double(id: 'fs-1'), double(id: 'fs-2'))
    allow(AtlasRb::FileSet).to receive(:update)
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig
    FileUtils.rm_rf(tmp_uploads)
  end

  it 'previews the ordered pages, then builds one Work with positioned FileSets and completes it once' do
    post '/loaders/postcards/loads',
         params: { load_report: { archive: fixture_archive('multipage'), parent_collection_id: 'neu:root' } }

    lr = LoadReport.last
    expect(lr).to be_previewing
    expect(lr.multipage_ingests.count).to eq(0)

    get loader_load_path(multipage_loader, lr)
    expect(response.body).to include('bdr_43889.tif').and include('bdr_43890.tif')
    expect(response.body).to include('Confirm')
    expect(response.body).to include('one Work')

    perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, lr) }

    lr.reload
    expect(lr).to be_completed
    expect(lr.multipage_ingests.completed.count).to eq(2)
    expect(lr.multipage_ingests.order(:sequence).pluck(:sequence, :source_filename))
      .to eq([[1, 'bdr_43889.tif'], [2, 'bdr_43890.tif']])

    expect(AtlasRb::Work).to have_received(:create).once
    expect(AtlasRb::FileSet).to have_received(:create)
      .with('w-new', 'image', position: 1, idempotency_key: kind_of(String))
    expect(AtlasRb::FileSet).to have_received(:create)
      .with('w-new', 'image', position: 2, idempotency_key: kind_of(String))
    expect(AtlasRb::FileSet).to have_received(:update).twice
    expect(AtlasRb::Work).to have_received(:complete).with('w-new').once
  end

  it 'blocks a bad-sequence archive at preview, and a forced confirm still mints nothing' do
    post '/loaders/postcards/loads',
         params: { load_report: { archive:              fixture_archive('multipage-bad-sequence'),
                                  parent_collection_id: 'neu:root' } }
    lr = LoadReport.last

    get loader_load_path(multipage_loader, lr)
    expect(response.body).to include('must run 1 through 2 with no gaps')
    expect(response.body).to include('Last Item is flagged on Sequence 1')
    expect(response.body).not_to include('Confirm &amp; run')

    perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, lr) }

    expect(lr.reload).to be_failed
    expect(AtlasRb::Work).not_to have_received(:create)
    expect(AtlasRb::FileSet).not_to have_received(:create)
    expect(AtlasRb::Work).not_to have_received(:complete)
  end

  it 'never completes the Work when a page fails' do
    allow(AtlasRb::FileSet).to receive(:update).and_raise(Faraday::ConnectionFailed.new('atlas down'))
    # Atlas agrees the pages never landed — otherwise the resumed-execution
    # verify guard would (correctly) treat the attach as already done.
    allow(AtlasRb::Work).to receive(:file_sets).and_return(
      [{ 'noid' => 'fs-1', 'position' => 1, 'assets' => [] },
       { 'noid' => 'fs-2', 'position' => 2, 'assets' => [] }]
    )

    post '/loaders/postcards/loads',
         params: { load_report: { archive: fixture_archive('multipage'), parent_collection_id: 'neu:root' } }
    perform_enqueued_jobs { patch confirm_loader_load_path(multipage_loader, LoadReport.last) }

    lr = LoadReport.last.reload
    expect(lr).to be_failed
    expect(lr.multipage_ingests.failed.count).to eq(2)
    expect(AtlasRb::Work).not_to have_received(:complete)
  end
end
