# frozen_string_literal: true

require 'rails_helper'

# The TUS 1.0.0 endpoint the large-file forms send their bytes to. Nothing here
# reaches Atlas: the endpoint only writes the staging volume.
RSpec.describe 'TUS uploads', type: :request do
  include Devise::Test::IntegrationHelpers

  include_context 'with a scratch uploads root'

  let(:user) do
    User.new(email: 'staff@example.com', password: 'password', nuid: '000000002',
             role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  let(:other) do
    User.new(email: 'other@example.com', password: 'password', nuid: '000000005', role: 'standard', groups: [])
  end
  let(:tus) { { 'Tus-Resumable' => '1.0.0' } }
  let(:chunk_headers) { tus.merge('CONTENT_TYPE' => 'application/offset+octet-stream') }

  def create_upload(length: 10, filename: 'scan.tif')
    post tus_uploads_path, headers: tus.merge(
      'Upload-Length'   => length.to_s,
      'Upload-Metadata' => "filename #{Base64.strict_encode64(filename)},filetype #{Base64.strict_encode64('image/tiff')}"
    )
    response.headers['Location'].split('/').last
  end

  it 'refuses a caller who is not signed in' do
    post tus_uploads_path, headers: tus.merge('Upload-Length' => '10')

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers['Tus-Resumable']).to eq('1.0.0')
  end

  context 'when signed in' do
    before { sign_in user }

    it 'describes the protocol on OPTIONS' do
      process :options, tus_uploads_path

      expect(response).to have_http_status(:no_content)
      expect(response.headers['Tus-Version']).to eq('1.0.0')
      expect(response.headers['Tus-Extension']).to eq('creation,termination')
    end

    it 'refuses a request without the protocol version' do
      post tus_uploads_path, headers: { 'Upload-Length' => '10' }

      expect(response).to have_http_status(:precondition_failed)
    end

    it 'creates an upload and points at it' do
      id = create_upload

      expect(response).to have_http_status(:created)
      expect(response.headers['Location']).to eq(tus_upload_url(id))
      expect(TusStore.find(id, owner_id: user.nuid).filename).to eq('scan.tif')
    end

    it 'refuses a creation with no length or no filename' do
      post tus_uploads_path, headers: tus.merge('Upload-Metadata' => "filename #{Base64.strict_encode64('a')}")
      expect(response).to have_http_status(:bad_request)

      post tus_uploads_path, headers: tus.merge('Upload-Length' => '10')
      expect(response).to have_http_status(:bad_request)
    end

    it 'takes chunks in order and reports the offset to resume from' do
      id = create_upload

      patch tus_upload_path(id), params: 'hello', headers: chunk_headers.merge('Upload-Offset' => '0')
      expect(response).to have_http_status(:no_content)
      expect(response.headers['Upload-Offset']).to eq('5')

      head tus_upload_path(id), headers: tus
      expect(response).to have_http_status(:ok)
      expect(response.headers.to_h).to include('upload-offset' => '5', 'upload-length' => '10',
                                               'cache-control' => 'no-store')
    end

    it 'answers a chunk for the wrong offset with 409' do
      id = create_upload

      patch tus_upload_path(id), params: 'hello', headers: chunk_headers.merge('Upload-Offset' => '3')

      expect(response).to have_http_status(:conflict)
    end

    it 'answers a chunk of the wrong content type with 415' do
      id = create_upload

      patch tus_upload_path(id), params: 'hello', headers: tus.merge('CONTENT_TYPE' => 'text/plain', 'Upload-Offset' => '0')

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it "hides another user's upload behind a 404" do
      id = create_upload
      sign_in other

      head tus_upload_path(id), headers: tus
      expect(response).to have_http_status(:not_found)

      patch tus_upload_path(id), params: 'hello', headers: chunk_headers.merge('Upload-Offset' => '0')
      expect(response).to have_http_status(:not_found)
    end

    it 'terminates an upload' do
      id = create_upload

      delete tus_upload_path(id), headers: tus

      expect(response).to have_http_status(:no_content)
      expect(TusStore.find(id, owner_id: user.nuid)).to be_nil
    end
  end
end
