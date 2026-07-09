# frozen_string_literal: true

require 'rails_helper'

# The "Upload File" affordance on the Work show page: add an arbitrary binary to
# an existing Work. Like the other resource-write specs, this runs against the
# live Atlas test backend — a real Work is created and a real edit ACL granted
# to the staff group, so authorize_resource_writes!'s :edit gate is exercised
# end-to-end. The attach itself is deferred to AddFileJob (asserted enqueued via
# the test adapter), so no Blob is actually written to Atlas here.
RSpec.describe 'Works upload (add a file)', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }
  let(:work)       { AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004') }

  # The staff user (000000002, in the staff edit group) passes both the Cerberus
  # group-ACL check and Atlas's enforced write authz once granted below.
  let(:editor) do
    User.new(email: 'editor@example.com', password: 'password', nuid: '000000002',
             name: 'Ed, Itor', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  # Authenticated but outside the edit group — Cerberus denies :edit.
  let(:outsider) do
    User.new(email: 'outsider@example.com', password: 'password',
             name: 'Out, Sider', role: 'standard', groups: ['randos'])
  end

  let(:upload) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/image.png'), 'image/png') }

  def grant_edit!
    AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } }, nuid: '000000004')
  end

  before { grant_edit! }

  # upload/add_file are edit-gated (not the authn-gated create surface), so an
  # unauthorized caller is a clean 403 — never a 200/redirect-to-success, and
  # never an enqueued attach.
  describe 'authorization' do
    it 'forbids the unauthenticated on the GET form' do
      get upload_work_path(work.id)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids the unauthenticated on POST and enqueues nothing' do
      expect do
        post upload_work_path(work.id), params: { binary: upload }
      end.not_to have_enqueued_job(AddFileJob)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids an authenticated non-editor on the GET form' do
      sign_in outsider
      get upload_work_path(work.id)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids an authenticated non-editor on POST and enqueues nothing' do
      sign_in outsider
      expect do
        post upload_work_path(work.id), params: { binary: upload }
      end.not_to have_enqueued_job(AddFileJob)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'as an in-group editor' do
    before { sign_in editor }

    it 'renders the upload form' do
      get upload_work_path(work.id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Upload a File')
    end

    it 'stages the upload, queues AddFileJob, and redirects to the work' do
      expect do
        post upload_work_path(work.id), params: { binary: upload }
      end.to have_enqueued_job(AddFileJob).with(work.id, kind_of(String), 'image.png', kind_of(String))
      expect(response).to redirect_to(work_path(work.id))
      expect(flash[:notice]).to be_present
    end

    it 'rejects a submission with no file, enqueues nothing, and flashes back to the form' do
      expect do
        post upload_work_path(work.id), params: {}
      end.not_to have_enqueued_job(AddFileJob)
      expect(response).to redirect_to(upload_work_path(work.id))
      expect(flash[:alert]).to be_present
    end
  end
end
