# frozen_string_literal: true

require 'rails_helper'

# HTTP/auth surface of the streamed Collection metadata export, end-to-end over
# the real test Atlas. The collection counterpart of set_exports_spec; the
# bundle's shape is unit-specced (metadata_export_packer_spec). Member Works
# resolve through the gated CollectionContentsResolver.
RSpec.describe 'Collection metadata exports', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:curator) do
    User.new(email: 'dps@example.com', password: 'password',
             nuid: '000000002', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  let(:reader) do
    User.new(email: 'reader@example.com', password: 'password',
             nuid: '000000009', role: 'standard')
  end

  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }

  it "streams a collection's member metadata as a zip for a loader-tier curator" do
    public_work(collection.id)
    sign_in curator

    get export_collection_path(collection.id)

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to include('application/zip')
    expect(response.headers['Content-Disposition']).to include('attachment')
      .and include("-#{collection.id}-metadata.zip")
  end

  it 'redirects with an alert when the collection has no member metadata' do
    sign_in curator

    get export_collection_path(collection.id)

    expect(response).to redirect_to(collection_path(collection.id))
    expect(flash[:alert]).to be_present
  end

  it 'bounces an anonymous visitor to sign in' do
    public_work(collection.id)

    get export_collection_path(collection.id)

    expect(response).to have_http_status(:redirect)
  end

  it 'forbids a signed-in non-loader' do
    public_work(collection.id)
    sign_in reader

    get export_collection_path(collection.id)

    expect(response).to have_http_status(:forbidden)
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
