# frozen_string_literal: true

require 'rails_helper'

# End-to-end over the real test Atlas: a created and completed Work is fetched
# and its Permanent URL row inspected. The partial's two branches are
# unit-specced (works/_permanent_url); this proves the show page reaches them —
# that the row is fed by `work.handle` and not by the dead MODS field, and that
# an unminted Work renders no row rather than an empty link.
#
# The test Atlas is deliberately given no handle client (see the atlas-test
# service in docker-compose.yml), so every Work it completes is unminted. That
# makes the absent case the honest one to run live, and the minted case is
# reached by putting a handle on the fetched Work.
RSpec.describe 'Work permanent URL', type: :request do
  let!(:community)  { public_container(AtlasRb::Community, nil) }
  let!(:collection) { public_container(AtlasRb::Collection, community.id) }
  let!(:work)       { public_work(collection.id) }

  # Matched on the trailing colon. The descriptive-metadata table below renders
  # the MODS `<identifier type="hdl" displayLabel="Permanent URL">` as a bare
  # `<dt>Permanent URL</dt>`, and the fixture carries one — so a match without
  # the colon finds that row instead and this example can never fail.
  it 'renders no Permanent URL row for a Work that was never minted' do
    get work_path(work.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('Permanent URL:')
    # The defect this replaces: `link_to nil, nil` emits an empty anchor.
    expect(response.body).not_to include('href=""')
  end

  # Pins the resolver rather than reading the configured one. A checkout with
  # the handles profile running sets HANDLE_RESOLVER_BASE to its own server, and
  # an expectation built on the default would fail there for no good reason.
  it 'links the resolved handle when Atlas has minted one' do
    allow(Rails.application.config.x.cerberus)
      .to receive(:handle_resolver_base).and_return('https://hdl.handle.net')
    minted = AtlasRb::Work.find(work.id)
    minted.handle = '2047/gq67jr519'
    allow(AtlasRb::Work).to receive(:find).with(work.id).and_return(minted)

    get work_path(work.id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Permanent URL:')
      .and include('https://hdl.handle.net/2047/gq67jr519')
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
