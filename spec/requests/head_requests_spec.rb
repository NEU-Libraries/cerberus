# frozen_string_literal: true

require 'rails_helper'

# HEAD answers with GET's status and headers and builds no body: no template,
# no data the template alone needs, no bytes from Atlas, no ZIP. Nor is it a
# view or a download. See docs/head-requests.md.
RSpec.describe 'HEAD requests', type: :request do
  include ActiveJob::TestHelper

  describe 'a page' do
    it 'answers with the status and type GET would, and no body' do
      head root_path

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(response.body).to be_empty
    end
  end

  describe 'a record page' do
    let!(:community)  { public_container(AtlasRb::Community, nil) }
    let!(:collection) { public_container(AtlasRb::Collection, community.id) }
    let!(:work)       { public_work(collection.id) }

    it 'answers a Work after its gates, without loading what only the page shows' do
      allow(AtlasRb::Work).to receive(:assets).and_call_original

      head work_path(work.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to be_empty
      expect(AtlasRb::Work).not_to have_received(:assets)
      expect(RecordImpressionJob).not_to have_been_enqueued
    end

    it 'gives a missing Work the 404 that GET gives' do
      head work_path('nosuchwork')

      expect(response).to have_http_status(:not_found)
    end

    it 'answers a Collection and a Community without listing their children' do
      expect_any_instance_of(CollectionsController).not_to receive(:prepare_show_view)
      expect_any_instance_of(CommunitiesController).not_to receive(:prepare_show_view)

      head collection_path(collection.id)
      expect(response).to have_http_status(:ok)

      head community_path(community.id)
      expect(response).to have_http_status(:ok)
      expect(RecordImpressionJob).not_to have_been_enqueued
    end
  end

  describe 'a file' do
    let(:blob_id) { 'b-321' }
    let(:public_perms) { AtlasRb::Mash.new('read' => ['public'], 'edit' => []) }
    let(:blob) do
      AtlasRb::Mash.new('mime_type' => 'application/pdf', 'filename' => 'scan.pdf', 'size' => 1000)
    end

    before do
      allow(AtlasRb::Resource).to receive(:permissions).with(blob_id).and_return(public_perms)
      allow(AtlasRb::Blob).to receive_messages(find: blob, work: 'w-1')
      allow(AtlasRb::Blob).to receive(:content).and_yield('bytes')
      allow(AtlasRb::Work).to receive(:assets).with('w-1', nuid: nil)
                                              .and_return([AtlasRb::Mash.new(noid: blob_id, gated: false)])
      allow(AtlasRb::Resource).to receive(:permissions).with('w-1').and_return(AtlasRb::Mash.new('embargo' => ''))
      allow(AtlasRb::Work).to receive(:find).with('w-1')
                                            .and_return(AtlasRb::Mash.new(in_progress: false, depositor: '000000004'))
    end

    it "sends a download's type and name without fetching its bytes or counting it" do
      head download_path(blob_id)

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/pdf')
      expect(response.headers['Content-Disposition']).to include('attachment').and include('scan.pdf')
      expect(AtlasRb::Blob).not_to have_received(:content)
      expect(RecordImpressionJob).not_to have_been_enqueued
    end

    it "sends media's whole length, ignoring Range, which HTTP defines for GET only" do
      head media_path(blob_id), headers: { 'Range' => 'bytes=0-499' }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Length']).to eq('1000')
      expect(response.headers['Accept-Ranges']).to eq('bytes')
      expect(response.headers).not_to have_key('Content-Range')
      expect(AtlasRb::Blob).not_to have_received(:content)
      expect(RecordImpressionJob).not_to have_been_enqueued
    end

    it 'still refuses what GET refuses' do
      allow(AtlasRb::Resource).to receive(:permissions)
        .with('w-1').and_return(AtlasRb::Mash.new('embargo' => (Date.current + 30).to_s))

      head media_path(blob_id)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'an archive' do
    it "sends the queue's ZIP headers without packing it" do
      post download_queue_items_path, params: { work_noid: 'w-1', blob_noid: 'b-1' }
      expect_any_instance_of(QueueZipPacker).not_to receive(:pack)

      head download_queue_archive_path

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/zip')
      expect(response.headers['Content-Disposition']).to include('attachment').and include('.zip')
      expect(response.body).to be_empty
    end
  end

  # --- helpers -------------------------------------------------------------

  def mods(kind) = Rails.root.join('spec/fixtures/files', "#{kind}-mods.xml").to_s
  def read_public = { 'read' => ['public'] }

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, mods(kind), nuid: '000000004')
    AtlasRb::Resource.set_permissions(container.id, read_public, nuid: '000000004')
    container
  end

  def public_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    AtlasRb::Resource.set_permissions(work.id, read_public, nuid: '000000004')
    work
  end
end
