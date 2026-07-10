# frozen_string_literal: true

require 'rails_helper'

# The per-blob download gate. Beyond the work-level authorize_show!,
# DownloadsController re-checks the blob's own read gate (`gated`/`permission` on
# the Work's assets payload) so a department-reserved master or rendition can't be
# pulled by its direct /downloads/:id URL even when the containing Work is public.
# Stubs the Atlas calls (like the derivative-download spec) to exercise the authz
# branch without a live backend; the work-level gate is stubbed to pass throughout.
RSpec.describe 'Blob downloads', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:blob_id) { 'b-1' }
  let(:work_id) { 'w-1' }

  before do
    allow(AtlasRb::Resource).to receive(:permissions).with(blob_id).and_return(
      AtlasRb::Mash.new('embargo' => '', 'depositor' => [], 'read' => ['public'], 'edit' => [])
    )
    allow(AtlasRb::Blob).to receive(:work).and_return(work_id)
  end

  # Only reached once the gate authorizes — stub the stream so show completes.
  def stub_stream!
    allow(AtlasRb::Blob).to receive(:find)
      .and_return(AtlasRb::Mash.new(mime_type: 'image/tiff', filename: 'master.tif'))
    allow(AtlasRb::Blob).to receive(:content).and_yield('bytes').and_return({})
  end

  def stub_asset(gated:, permission:, nuid:, classification: nil)
    allow(AtlasRb::Work).to receive(:assets).with(work_id, nuid: nuid)
                                            .and_return([AtlasRb::Mash.new(noid: blob_id, gated: gated,
                                                                           permission: permission, classification: classification)])
  end

  it 'streams an ungated blob to a guest' do
    stub_asset(gated: false, permission: ['public'], nuid: nil)
    stub_stream!

    get download_path(blob_id)

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Disposition']).to include('master.tif')
  end

  # The Live stream carries no Content-Length; without this a buffering proxy
  # (nginx) accumulates and truncates the download. See ProxyUnbuffered.
  it 'marks the streamed download un-bufferable for the proxy' do
    stub_asset(gated: false, permission: ['public'], nuid: nil)
    stub_stream!

    get download_path(blob_id)

    expect(response.headers['X-Accel-Buffering']).to eq('no')
  end

  # A blob Atlas could not identify (classification "File") is delivered as a
  # zip generated on the fly — grounded (the UI promises a "Zip File") and inert.
  it 'wraps a generic (unidentifiable) blob in a zip on the fly' do
    stub_asset(gated: false, permission: ['public'], nuid: nil, classification: 'File')
    stub_stream!

    get download_path(blob_id)

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to eq('application/zip')
    expect(response.headers['Content-Disposition']).to include('master.zip') # base from blob.filename
  end

  # The discriminator is the classification, not the label: a typed blob (and,
  # crucially, a real "Archive" upload — already a zip) streams raw, unwrapped.
  it 'streams a typed blob raw rather than zipping it' do
    stub_asset(gated: false, permission: ['public'], nuid: nil, classification: 'Image')
    stub_stream!

    get download_path(blob_id)

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to eq('image/tiff')
    expect(response.headers['Content-Disposition']).to include('master.tif')
  end

  it 'forbids a gated blob for a guest (permission withheld)' do
    stub_asset(gated: true, permission: nil, nuid: nil)

    get download_path(blob_id)

    expect(response).to have_http_status(:forbidden)
  end

  it 'forbids a gated blob for a signed-in non-member' do
    sign_in User.new(email: 'o@x.edu', password: 'password', nuid: '000000005', groups: ['g:other'])
    stub_asset(gated: true, permission: ['g:arch'], nuid: '000000005')

    get download_path(blob_id)

    expect(response).to have_http_status(:forbidden)
  end

  it 'streams a gated blob to a member of a gating group' do
    sign_in User.new(email: 'm@x.edu', password: 'password', nuid: '000000004', groups: ['g:arch'])
    stub_asset(gated: true, permission: ['g:arch'], nuid: '000000004')
    stub_stream!

    get download_path(blob_id)

    expect(response).to have_http_status(:ok)
  end

  it 'fails open (streams) when the blob is absent from the work assets' do
    allow(AtlasRb::Work).to receive(:assets).with(work_id, nuid: nil).and_return([])
    stub_stream!

    get download_path(blob_id)

    expect(response).to have_http_status(:ok)
  end

  it 'fails open (streams) when the containing work is unresolvable' do
    allow(AtlasRb::Blob).to receive(:work).and_return(nil)
    stub_stream!

    get download_path(blob_id)

    expect(response).to have_http_status(:ok)
  end
end
