# frozen_string_literal: true

require 'rails_helper'

# Small in surface, deliberately full-fat: real credentials, a real Atlas
# round-trip, real Solr, and a real render through the application layout.
# It answers one question — is this checkout wired up correctly? — and leaves
# "is the code correct" to the full suite, which CI runs on every push.
#
# Each example stands in for a failure that has cost a debugging session, and
# each is written to fail with its own cause rather than as one of a hundred
# unrelated red examples:
#
#   credentials  a worktree carries no config/master.key (gitignored, so
#                `git worktree add` never brings it), every credential resolves
#                nil, and atlas_rb cannot sign a single request.
#   layout       a fresh worktree has no app/assets/builds/application.css
#                (a build artifact, also gitignored), so Propshaft raises on
#                every page that renders the layout — which reads as unrelated
#                500s in authz specs.
#   index        Atlas indexes on write; if Solr is unreachable or the run is
#                pointed at the wrong core, discovery silently returns nothing
#                and the failure looks like a data problem.
#
# Tagged :smoke so the worktree gate can run this alone. Not to be confused
# with :loc_smoke, which marks the opt-in live Library of Congress calls.
RSpec.describe 'Environment smoke', :smoke, type: :request do
  it 'signs an Atlas write with the application credentials' do
    expect(Rails.application.credentials.cerberus_signing_key).to be_present

    community = AtlasRb::Community.create(nil, mods('community'), nuid: nuid)

    expect(community&.id).to be_present
  end

  it 'renders a page through the application layout' do
    get root_path

    expect(response).to have_http_status(:ok)
  end

  it 'renders the catalog, which reaches Solr through Blacklight' do
    get search_catalog_path(q: '', search_field: 'all_fields')

    expect(response).to have_http_status(:ok)
  end

  it 'indexes a new public work into Solr and renders its page' do
    work = public_work

    # Queried by noid rather than by keyword: a keyword search would depend on
    # the search-field configuration and on this work landing on page one of a
    # shared store that other specs have filled.
    docs = Blacklight.default_index.search(
      q: '*:*', fq: ["alternate_ids_ssim:\"id-#{work.id}\""], rows: 1
    ).documents

    expect(docs.map(&:to_param)).to eq([work.id])

    get work_path(work.id)

    expect(response).to have_http_status(:ok)
  end

  # --- helpers ---------------------------------------------------------------

  def nuid = '000000004'

  # Rails.root-relative so the fixture resolves to whichever checkout is running
  # — a worktree run would otherwise read the develop checkout's copy through
  # the container's bind mount.
  def mods(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s

  def read_public = { 'permissions' => { 'read' => ['public'] } }

  # A public Work needs public containers above it: Atlas refuses a resource
  # more visible than its parent, so each tier is widened on the way down.
  def public_work
    collection = public_collection(public_community.id)
    work = AtlasRb::Work.create(collection.id, mods('work'), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Work.metadata(work.id, read_public, nuid: nuid)
    work
  end

  def public_community
    community = AtlasRb::Community.create(nil, mods('community'), nuid: nuid)
    AtlasRb::Community.metadata(community.id, read_public, nuid: nuid)
    community
  end

  def public_collection(parent_id)
    collection = AtlasRb::Collection.create(parent_id, mods('collection'), nuid: nuid)
    AtlasRb::Collection.metadata(collection.id, read_public, nuid: nuid)
    collection
  end
end
