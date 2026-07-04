# frozen_string_literal: true

require 'rails_helper'

# HTTP/session surface of the Download Queue. The session is DB-backed (AR
# store) and persists across requests within an example, so add/remove/clear
# round-trip through it. Blob-level packing is unit-specced (queue_zip_packer);
# real-content packing is verified in-browser. Anon-capable throughout.
RSpec.describe 'Download queue', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:community) { public_container(AtlasRb::Community, nil) }
  let!(:work)      { public_work(community.id) }

  it 'adds a file, then shows it on the queue page with a count' do
    post download_queue_items_path, params: { work_noid: work.id, blob_noid: 'blob1' }

    get download_queue_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('1 file').and include(work.id)
  end

  it 'updates the navbar badge via turbo_stream on add' do
    post download_queue_items_path,
         params:  { work_noid: work.id, blob_noid: 'blob1' },
         headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

    expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    expect(response.body).to include('download-queue-nav').and include('queue-control-blob1')
  end

  it 'does not double-add the same file' do
    2.times { post download_queue_items_path, params: { work_noid: work.id, blob_noid: 'blob1' } }
    get download_queue_path
    expect(response.body).to include('1 file')
  end

  it 'removes a file' do
    post download_queue_items_path, params: { work_noid: work.id, blob_noid: 'blob1' }
    delete download_queue_item_path, params: { work_noid: work.id, blob_noid: 'blob1' }
    follow_redirect!
    expect(response.body).to include('Your download queue is empty')
  end

  it 'clears the queue' do
    post download_queue_items_path, params: { work_noid: work.id, blob_noid: 'blob1' }
    delete download_queue_path
    follow_redirect!
    expect(response.body).to include('Your download queue is empty')
  end

  it 'streams a zip for a non-empty queue (anonymous)' do
    post download_queue_items_path, params: { work_noid: work.id, blob_noid: 'blob1' }

    get download_queue_archive_path
    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to include('application/zip')
    expect(response.headers['Content-Disposition']).to include('attachment').and include('.zip')
  end

  it 'redirects when downloading an empty queue' do
    get download_queue_archive_path
    expect(response).to redirect_to(download_queue_path)
    expect(flash[:alert]).to be_present
  end

  # --- helpers -------------------------------------------------------------

  def mods(kind) = "/home/cerberus/web/spec/fixtures/files/#{kind}-mods.xml"
  def read_public = { 'permissions' => { 'read' => ['public'] } }

  def public_container(klass, parent_id)
    kind = klass.name.demodulize.downcase
    container = klass.create(parent_id, mods(kind), nuid: '000000004')
    klass.metadata(container.id, read_public, nuid: '000000004')
    container
  end

  def public_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: '000000004')
    AtlasRb::Work.complete(work.id, nuid: '000000004')
    AtlasRb::Work.metadata(work.id, read_public, nuid: '000000004')
    work
  end
end
