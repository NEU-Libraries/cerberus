# frozen_string_literal: true

require 'rails_helper'

# Proves the controller wire-in: visiting a Work/Collection/Community show page
# enqueues a 'view' impression, and a download enqueues a 'download' keyed by
# the blob id (the job resolves the work later). queue_adapter is :test in this
# env, so the job is asserted enqueued, not performed. Request specs (Warden).
RSpec.describe 'Impression capture', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  describe 'view capture (public, guest)' do
    let!(:community)  { public_container(AtlasRb::Community, nil) }
    let!(:collection) { public_container(AtlasRb::Collection, community.id) }

    it 'enqueues a view impression on the Work show page' do
      work = public_work(collection.id)

      get work_path(work.id)

      expect(response).to have_http_status(:ok)
      expect(RecordImpressionJob).to have_been_enqueued
        .with(hash_including(action: 'view', noid: work.id))
    end

    it 'enqueues a view impression on the Collection show page' do
      get collection_path(collection.id)

      expect(response).to have_http_status(:ok)
      expect(RecordImpressionJob).to have_been_enqueued
        .with(hash_including(action: 'view', noid: collection.id))
    end

    it 'enqueues a view impression on the Community show page' do
      get community_path(community.id)

      expect(response).to have_http_status(:ok)
      expect(RecordImpressionJob).to have_been_enqueued
        .with(hash_including(action: 'view', noid: community.id))
    end
  end

  describe 'download capture' do
    let(:blob_id) { 'b-321' }
    let(:public_perms) { AtlasRb::Mash.new('read' => ['public'], 'edit' => []) }

    before do
      allow(AtlasRb::Resource).to receive(:permissions).with(blob_id).and_return(public_perms)
      allow(AtlasRb::Blob).to receive(:find).with(blob_id)
                                            .and_return(AtlasRb::Mash.new('mime_type' => 'application/pdf', 'filename' => 'scan.pdf'))
      allow(AtlasRb::Blob).to receive(:content).with(blob_id).and_yield('bytes')
    end

    it 'enqueues a download impression keyed by the blob id' do
      get download_path(blob_id)

      expect(RecordImpressionJob).to have_been_enqueued
        .with(hash_including(action: 'download', blob_id: blob_id))
    end
  end

  # --- helpers -------------------------------------------------------------

  def mods(kind) = Rails.root.join('spec/fixtures/files', "#{kind}-mods.xml").to_s
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
