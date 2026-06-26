# frozen_string_literal: true

require 'rails_helper'

# The seekable inline media endpoint. Bytes are stubbed (the Range relay logic +
# impression recording are what's under test, not Atlas streaming).
RSpec.describe 'Media', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:blob) { AtlasRb::Mash.new('mime_type' => 'video/mp4', 'filename' => 'movie.mp4', 'size' => 1000) }
  let(:public_perms) { AtlasRb::Mash.new('read' => ['public'], 'edit' => []) }

  before do
    allow(AtlasRb::Resource).to receive(:permissions).with('b1').and_return(public_perms)
    allow(AtlasRb::Blob).to receive(:find).with('b1').and_return(blob)
    allow(AtlasRb::Blob).to receive(:content).and_yield('bytes').and_return({ status: 206, headers: {} })
  end

  it 'serves a 206 with Content-Range for a ranged request' do
    get '/media/b1', headers: { 'Range' => 'bytes=0-499' }

    expect(response).to have_http_status(:partial_content)
    expect(response.headers['Content-Range']).to eq('bytes 0-499/1000')
    expect(response.headers['Accept-Ranges']).to eq('bytes')
  end

  it 'serves a 200 with Accept-Ranges for a full request' do
    get '/media/b1'

    expect(response).to have_http_status(:ok)
    expect(response.headers['Accept-Ranges']).to eq('bytes')
  end

  it 'records a stream impression for a ranged request' do
    get '/media/b1', headers: { 'Range' => 'bytes=0-499' }

    expect(RecordImpressionJob).to have_been_enqueued.with(hash_including(action: 'stream', blob_id: 'b1'))
  end

  it 'records a download impression for a full request' do
    get '/media/b1'

    expect(RecordImpressionJob).to have_been_enqueued.with(hash_including(action: 'download', blob_id: 'b1'))
  end
end
