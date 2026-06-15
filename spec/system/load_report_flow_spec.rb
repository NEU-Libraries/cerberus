# frozen_string_literal: true

require 'rails_helper'

# End-to-end batch-flow spec. Exercises the full piece 4 chain:
# LoadsController#create → UnzipJob → IptcIngestJob × N →
# ContentCreationJob.perform_later (mocked) + IiifAssetsJob.perform_later
# (mocked) → finalize_success → LoadReport.maybe_finalize!.
#
# Iptc::Extractor is mocked (the test environment may not have a real
# exiftool binary available in every CI lane; per-extractor parsing is
# covered exhaustively by spec/services/iptc/extractor_spec.rb).
# Atlas calls are mocked (no network in tests; integration is covered
# by atlas_rb's own suite).
RSpec.describe 'LoadReport end-to-end batch flow', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let!(:marcom_loader) do
    Loader.create!(
      slug:            'marcom',
      display_name:    'Marketing and Communications',
      group:           'northeastern:drs:repository:loaders:marcom',
      root_collection: 'neu:fix-comm-photos-archive'
    )
  end

  let(:marcom_user) do
    User.new(email: 'marcom@example.com', password: 'password',
             nuid: '000000003', role: 'loader',
             groups: ['northeastern:drs:repository:loaders:marcom'])
  end

  let(:tmp_uploads) { Dir.mktmpdir('iptc-flow') }

  before do
    @orig_uploads_root = Rails.application.config.x.cerberus.uploads_root
    Rails.application.config.x.cerberus.uploads_root = tmp_uploads
    sign_in marcom_user

    # Atlas Collection lookups for the picker
    allow(AtlasRb::Collection).to receive(:children)
      .with('neu:fix-comm-photos-archive')
      .and_return(['neu:c1'])
    allow(AtlasRb::Collection).to receive(:find).with('neu:c1')
                                                .and_return(double(id: 'neu:c1', title: 'Campus Life (Photographs)'))

    # Atlas Work mint — IptcIngestJob#ensure_work calls this
    allow(AtlasRb::Work).to receive(:create) { double(id: "w-#{SecureRandom.hex(4)}") }

    # Downstream jobs — covered by their own specs; mock the enqueue
    # so we don't depend on Cantaloupe / image-processing in this lane.
    allow(ContentCreationJob).to receive(:perform_later)
    allow(IiifAssetsJob).to receive(:perform_later)

    # Mock Iptc::Extractor so the spec doesn't require the exiftool
    # binary on every CI lane. Per-tag parsing covered by extractor_spec.
    allow(Iptc::Extractor).to receive(:call) do |path:|
      Iptc::Extractor::Result.new(
        tags: {
          Headline: "Photo for #{File.basename(path)}",
          Keywords: %w[athletics campus]
        },
        width: 3000, height: 2000
      )
    end
  end

  after do
    Rails.application.config.x.cerberus.uploads_root = @orig_uploads_root
    FileUtils.rm_rf(tmp_uploads)
  end

  let(:archive) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec/fixtures/files/jpgs.zip'),
      'application/zip'
    )
  end

  it 'walks an upload through UnzipJob and per-image IptcIngestJobs to LoadReport completion' do
    perform_enqueued_jobs do
      post '/loaders/marcom/loads',
           params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
    end

    lr = LoadReport.last
    expect(lr).not_to be_nil, 'LoadReport should have been created by LoadsController#create'
    expect(lr.loader).to eq(marcom_loader)
    expect(lr.parent_collection_id).to eq('neu:c1')

    # UnzipJob created one IptcIngest per JPEG in the archive
    expect(lr.iptc_ingests.count).to be > 0,
                                     "UnzipJob should have created IptcIngest rows for the archive's JPEGs"

    # Every IptcIngest reached :completed (mocked Extractor returns
    # valid Headline + Keywords, so ModsBuilder doesn't raise)
    expect(lr.iptc_ingests.completed.count).to eq(lr.iptc_ingests.count)

    # LoadReport finalized via maybe_finalize! after the last IptcIngestJob
    expect(lr.reload).to be_completed

    # Each ingest enqueued the downstream chain (mocked)
    expect(ContentCreationJob).to have_received(:perform_later).exactly(lr.iptc_ingests.count).times
    expect(IiifAssetsJob).to have_received(:perform_later).exactly(lr.iptc_ingests.count).times

    # Each Work created with the right parent collection + a unique idempotency key
    expect(AtlasRb::Work).to have_received(:create).exactly(lr.iptc_ingests.count).times do |parent, _path, idempotency_key:|
      expect(parent).to eq('neu:c1')
      expect(idempotency_key).to be_a(String).and(be_present)
    end
  end

  it 'redirects to the LoadReport show page after the upload kicks off' do
    perform_enqueued_jobs do
      post '/loaders/marcom/loads',
           params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
    end

    expect(response).to redirect_to(loader_load_path(marcom_loader, LoadReport.last))
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  context 'when an image has missing required IPTC fields' do
    before do
      # Half the images have valid IPTC, half are missing Headline.
      call_count = 0
      allow(Iptc::Extractor).to receive(:call) do |**_|
        call_count += 1
        tags = if call_count.even?
                 { Keywords: ['x'] } # no Headline → MissingRequiredField
               else
                 { Headline: 'OK', Keywords: ['athletics'] }
               end
        Iptc::Extractor::Result.new(tags: tags, width: 3000, height: 2000)
      end
    end

    it 'finalizes the LoadReport as :failed when any ingest fails' do
      perform_enqueued_jobs do
        post '/loaders/marcom/loads',
             params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
      end

      lr = LoadReport.last
      expect(lr.iptc_ingests.failed.count).to be > 0
      expect(lr.reload).to be_failed
    end

    it 'sends exactly one inbox notification despite the mixed completed/failed batch' do
      # Regression for the premature-finalize flap: with incremental row
      # creation a fast worker finalized the report early (completed) and again
      # on convergence (failed), emitting *two* inbox messages for one load.
      # Two-phase fan-out closes that window — every row exists before any job
      # runs, so finalization (and the notification) happens exactly once.
      expect do
        perform_enqueued_jobs do
          post '/loaders/marcom/loads',
               params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
        end
      end.to change(Message, :count).by(1)

      expect(LoadReport.last.reload).to be_failed
      # The single message reflects the true terminal state — we didn't merely
      # suppress the second message and keep a premature "completed" first one.
      expect(Message.last.subject).to end_with('failed')
    end
  end

  context 'when extraction produces warnings (non-Time DateTimeOriginal)' do
    before do
      allow(Iptc::Extractor).to receive(:call) do |**_|
        Iptc::Extractor::Result.new(
          tags: {
            Headline:         'OK',
            Keywords:         ['athletics'],
            DateTimeOriginal: 'not-a-time-string' # triggers ModsBuilder warning
          },
          width: 3000, height: 2000
        )
      end
    end

    it 'finalizes the LoadReport as :completed_with_warnings' do
      perform_enqueued_jobs do
        post '/loaders/marcom/loads',
             params: { load_report: { archive: archive, parent_collection_id: 'neu:c1' } }
      end

      lr = LoadReport.last
      expect(lr.iptc_ingests.completed_with_warnings.count).to eq(lr.iptc_ingests.count)
      expect(lr.reload).to be_completed_with_warnings
    end
  end
end
