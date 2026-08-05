# frozen_string_literal: true

require 'rails_helper'

# HTTP/auth surface of the streamed bulk-set download, end-to-end over the
# real test Atlas (compilations + works created through AtlasRb, contents
# resolved against the same Solr). The packer's filtering/naming is unit-
# specced (set_zip_packer_spec); the gated enumeration in set_resolver_spec.
# Works here are metadata shells — enough to exercise gating, the empty guard,
# and the streamed-zip response contract without content-blob fixtures.
RSpec.describe 'Set downloads', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:curator) do
    User.new(email: 'dps@example.com', password: 'password',
             nuid: '000000002', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }
  let!(:work)       { public_work(collection.id) }

  it "streams a public set's content as a zip to an anonymous visitor" do
    set = make_set('Smith Thesis Materials')
    add_work(set, work)
    make_public(set)
    sign_out_all

    get download_set_path(set['id'])

    expect(response).to have_http_status(:ok)
    expect(response.headers['Content-Type']).to include('application/zip')
    expect(response.headers['Content-Disposition']).to include('attachment')
      .and include("smith-thesis-materials-#{set['id']}.zip")
  end

  it 'redirects with a notice when the set has no downloadable content' do
    sign_in curator
    set = make_set('Empty Set')

    get download_set_path(set['id'])

    expect(response).to redirect_to(set_path(set['id']))
    expect(flash[:alert]).to be_present
  end

  it '403s an anonymous visitor on a private set' do
    set = make_set('Private Set')
    add_work(set, work)
    sign_out_all

    get download_set_path(set['id'])

    expect(response).to have_http_status(:forbidden)
  end

  it '404s an unknown set id' do
    get download_set_path('zzzzzzz')
    expect(response).to have_http_status(:not_found)
  end

  # The single-file routes all resolve as the View-as target, so the archive has
  # to as well — otherwise an admin checking someone's reach is refused a file
  # and handed that same file inside the zip.
  it 'builds the archive as the view-as target, not the impersonating admin' do
    set = make_set('View-as Set')
    add_work(set, work)
    make_public(set)
    enter_view_as('000000010')

    expect(SetZipPacker).to receive(:new)
      .with(hash_including(nuid: '000000010', bypass_embargo: false))
      .and_call_original

    get download_set_path(set['id'])
  end

  # --- helpers -------------------------------------------------------------

  def nuid = '000000002'
  def mods(kind) = "/home/cerberus/web/spec/fixtures/files/#{kind}-mods.xml"
  def read_public = { 'permissions' => { 'read' => ['public'] } }

  # Compilation create + recipe writes go through HTTP as the owning curator;
  # then we sign out to assert the anonymous read path.
  def make_set(title)
    sign_in curator
    AtlasRb::Compilation.create(title, nuid: nuid)
  end

  def add_work(set, work)
    post "/sets/#{set['id']}/works", params: { work_id: work.id }
  end

  def make_public(set)
    AtlasRb::Compilation.update(set['id'],
                                permissions: { read: ['public'], edit: [], edit_users: [] },
                                nuid:        nuid)
  end

  def sign_out_all = sign_out(curator)

  # An admin (who can bypass an embargo) standing in for a plain reader (who
  # cannot). Hydration is the same GET /user that SSO sign-in makes; the session
  # start emits an audit event we don't need to reach Atlas.
  def enter_view_as(target_nuid)
    sign_out_all
    sign_in User.new(email: 'admin@example.com', password: 'password',
                     nuid: '000000004', name: 'User, Admin', role: 'admin')
    allow(AtlasRb::AuditEvent).to receive(:emit)
    allow(AtlasRb::Authentication).to receive(:login).with(target_nuid).and_return(
      AtlasRb::Mash.new('nuid' => target_nuid, 'name' => 'Reader, Plain',
                        'email' => "#{target_nuid}@neu.edu", 'role' => 'standard', 'groups' => [])
    )
    post admin_view_as_path, params: { nuid: target_nuid }
  end

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
