# frozen_string_literal: true

require 'rails_helper'

# HTTP/auth surface of the streamed Set metadata export, end-to-end over the
# real test Atlas. The bundle's shape is unit-specced (metadata_export_packer_spec);
# this owns the loader gate, the empty guard, and the streamed-zip contract.
# Unlike the bulk download, export is a librarian tool gated to the loader tier,
# so the auth expectations differ: anonymous is bounced to login, a signed-in
# non-loader is forbidden.
RSpec.describe 'Set metadata exports', type: :request do
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
  let!(:work)       { public_work(collection.id) }

  it 'streams a set as a metadata zip for a loader-tier curator' do
    set = make_set('Smith Thesis Materials')
    add_work(set, work)

    get export_set_path(set['id'])

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to include('application/zip')
    expect(response.headers['Content-Disposition']).to include('attachment')
      .and include("smith-thesis-materials-#{set['id']}-metadata.zip")
  end

  it 'redirects with an alert when the set has no metadata to export' do
    sign_in curator
    set = make_set('Empty Set')

    get export_set_path(set['id'])

    expect(response).to redirect_to(set_path(set['id']))
    expect(flash[:alert]).to be_present
  end

  it 'bounces an anonymous visitor to sign in' do
    set = make_set('Some Set')
    add_work(set, work)
    sign_out_all

    get export_set_path(set['id'])

    expect(response).to have_http_status(:redirect)
  end

  it 'forbids a signed-in non-loader' do
    set = make_set('Some Set')
    add_work(set, work)
    sign_out_all
    sign_in reader

    get export_set_path(set['id'])

    expect(response).to have_http_status(:forbidden)
  end

  it '404s an unknown set id for a loader' do
    sign_in curator
    get export_set_path('zzzzzzz')
    expect(response).to have_http_status(:not_found)
  end

  # --- helpers -------------------------------------------------------------

  def nuid = '000000002'
  def mods(kind) = "/home/cerberus/web/spec/fixtures/files/#{kind}-mods.xml"
  def read_public = { 'permissions' => { 'read' => ['public'] } }

  def make_set(title)
    sign_in curator
    AtlasRb::Compilation.create(title, nuid: nuid)
  end

  def add_work(set, work)
    post "/sets/#{set['id']}/works", params: { work_id: work.id }
  end

  def sign_out_all = sign_out(curator)

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
