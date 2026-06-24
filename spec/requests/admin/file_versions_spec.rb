# frozen_string_literal: true

require 'rails_helper'

# Admin file-version content streaming — the "download a superseded version"
# half of the replace surface. The gate is stub-free (it short-circuits before
# the action body); the streaming happy-path runs against the live test Atlas,
# the same way DownloadsController's spec does, to avoid stubbing inside the
# ActionController::Live worker thread.
RSpec.describe 'Admin::FileVersions', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  describe 'admin gate' do
    it 'forbids :privileged staff' do
      sign_in staff_user
      get '/admin/files/b1/versions/v1/content'
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects the unauthenticated to sign-in' do
      get '/admin/files/b1/versions/v1/content'
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'streaming a version (live Atlas)' do
    let(:fixtures) { Rails.root.join('spec/fixtures/files') }
    let(:community) { AtlasRb::Community.create(nil, fixtures.join('community-mods.xml').to_s, nuid: '000000004') }
    let(:collection) { AtlasRb::Collection.create(community.id, fixtures.join('collection-mods.xml').to_s, nuid: '000000004') }
    let(:work) { AtlasRb::Work.create(collection.id, fixtures.join('work-mods.xml').to_s, nuid: '000000004') }
    let(:noid) do
      AtlasRb::Blob.create(work.id, fixtures.join('image.png').to_s, 'image.png', nuid: '000000004')
      AtlasRb::Work.assets(work.id, nuid: '000000004').first.noid
    end

    before { sign_in admin_user }

    it 'streams the version with a version-suffixed attachment filename' do
      version_id = AtlasRb::Blob.versions(noid, nuid: '000000004')['versions'].last['version_id']

      get "/admin/files/#{noid}/versions/#{version_id}/content"

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('image/png')
      # The version label is suffixed onto the basename; the parens get
      # percent-encoded by ContentDisposition, so assert on the bare label.
      expect(response.headers['Content-Disposition']).to include('attachment', version_id)
    end
  end
end
