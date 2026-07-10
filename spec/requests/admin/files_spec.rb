# frozen_string_literal: true

require 'rails_helper'

# Admin replace-a-file surface: find a Work → manage its Blobs (replace / view
# versions / revert). atlas_rb + the resource search are stubbed; these exercise
# the Cerberus controller/view wiring, not Atlas or Solr.
RSpec.describe 'Admin::Files', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  def doc(noid:, title:, klass: 'Work')
    SolrDocument.new('id'                      => "uuid-#{noid}",
                     'alternate_ids_tesim'     => ["id-#{noid}"],
                     'internal_resource_tesim' => klass,
                     'title_tsim'              => [title])
  end

  def fake_results(*docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  let(:upload) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files/image.png'), 'image/png') }

  describe 'admin gate' do
    context 'as :privileged staff' do
      before { sign_in staff_user }

      it 'forbids every action' do
        get '/admin/files'
        expect(response).to have_http_status(:forbidden)
        get '/admin/files/manage', params: { work_id: 'w' }
        expect(response).to have_http_status(:forbidden)
        post '/admin/files/replace', params: { work_id: 'w', blob_noid: 'b' }
        expect(response).to have_http_status(:forbidden)
        post '/admin/files/rollback', params: { work_id: 'w', blob_noid: 'b', version_id: 'v1' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'unauthenticated' do
      it 'redirects to sign-in' do
        get '/admin/files'
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'as admin' do
    before { sign_in admin_user }

    describe 'GET index' do
      it 'finds works by keyword' do
        allow(ResourceSearch).to receive(:call)
          .and_return(fake_results(doc(noid: 'w1', title: 'A Photograph')))
        get '/admin/files', params: { q: 'photo' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('A Photograph', 'w1', 'Manage files')
      end
    end

    describe 'GET manage' do
      before do
        allow(AtlasRb::Work).to receive(:find).with('w1').and_return(OpenStruct.new(title: 'A Photograph'))
        allow(AtlasRb::Work).to receive(:assets).with('w1').and_return(
          [
            AtlasRb::Mash.new('noid' => 'b1', 'label' => 'report.pdf', 'use' => 'content',
                              'mime_type' => 'application/pdf', 'size' => 1234),
            AtlasRb::Mash.new('noid' => 'd1', 'label' => 'A thumbnail delegate', 'uri' => 'http://img/thumb',
                              'mime_type' => 'image/jpeg')
          ]
        )
        # revision is the contiguous ordinal; version_id is the raw OCFL label,
        # which skips (v4 for revision 2) after a preservation-envelope bump.
        allow(AtlasRb::Blob).to receive(:versions).with('b1').and_return(
          AtlasRb::Mash.new('versions' => [
                              { 'revision' => 2, 'version_id' => 'v4', 'created' => '2026-06-24T10:00:00Z',
                                'actor_nuid' => '000000004', 'digest' => 'sha512:aaaa' },
                              { 'revision' => 1, 'version_id' => 'v1', 'created' => '2026-06-20T09:00:00Z',
                                'actor_nuid' => '000000002', 'digest' => 'sha512:bbbb' }
                            ])
        )
      end

      it 'lists replaceable content Blobs with their version history and a replace form' do
        get '/admin/files/manage', params: { work_id: 'w1' }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('A Photograph', 'report.pdf', 'b1', 'Replace file', 'v4', 'v1')
      end

      it 'headlines the revision ordinal and demotes the raw OCFL version_id to a secondary label' do
        get '/admin/files/manage', params: { work_id: 'w1' }
        html = response.parsed_body
        headlines  = html.css('.admin-registry-table__id').map { |n| n.text.strip }
        secondary  = html.css('.admin-registry-table__vid').map { |n| n.text.strip }
        # Revision ordinals lead as the primary chip...
        expect(headlines).to include('2', '1')
        # ...while the skipping OCFL labels ride below as secondary/debug.
        expect(secondary).to eq(%w[v4 v1])
      end

      it 'excludes derived Delegates (those with a uri), which are not replaceable' do
        get '/admin/files/manage', params: { work_id: 'w1' }
        expect(response.body).not_to include('A thumbnail delegate')
      end

      it 'offers Revert on prior versions but not the current one' do
        get '/admin/files/manage', params: { work_id: 'w1' }
        # one Revert button (for v1); v2 is current, so it gets none.
        expect(response.body.scan('Revert').size).to eq(1)
      end
    end

    describe 'POST replace' do
      it 'stages the upload, queues a replacement, and redirects to manage' do
        expect do
          post '/admin/files/replace', params: { work_id: 'w1', blob_noid: 'b1', binary: upload }
        end.to have_enqueued_job(FileReplacementJob)
          .with('b1', 'w1', kind_of(String), 'image.png', kind_of(String))
        expect(response).to redirect_to(admin_files_manage_path(work_id: 'w1'))
      end

      it 'rejects a submission with no file' do
        expect do
          post '/admin/files/replace', params: { work_id: 'w1', blob_noid: 'b1' }
        end.not_to have_enqueued_job(FileReplacementJob)
        expect(response).to redirect_to(admin_files_manage_path(work_id: 'w1'))
        expect(flash[:alert]).to be_present
      end
    end

    describe 'POST rollback' do
      it 'reverts the Blob to a prior version and refreshes derivatives' do
        expect(AtlasRb::Blob).to receive(:rollback).with('b1', 'v1')
        expect do
          post '/admin/files/rollback', params: { work_id: 'w1', blob_noid: 'b1', version_id: 'v1' }
        end.to have_enqueued_job(FileDerivativeRefreshJob).with('w1', 'b1')
        expect(response).to redirect_to(admin_files_manage_path(work_id: 'w1'))
      end
    end
  end
end
