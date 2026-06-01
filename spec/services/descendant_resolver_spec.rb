# frozen_string_literal: true

require 'rails_helper'

# Builds a small hierarchy directly via AtlasRb (Atlas indexes synchronously,
# including ancestor_ids_ssim), then exercises the two-step resolver against it:
#
#   community
#   ├── collection_a
#   │   ├── work_a            (home)
#   │   └── sub_collection
#   │       └── work_sub      (home)
#   └── collection_b
#       └── work_b            (home; linked into collection_a in one example)
#
# Everything is made public so that, with both resolution steps gated for an
# anonymous user, the intermediate containers (step 1) and the Works (step 2) are
# all discoverable. Gating is exercised explicitly by a separately-restricted Work.
RSpec.describe DescendantResolver do
  let!(:community)      { public_community }
  let!(:collection_a)   { public_collection(community.id) }
  let!(:collection_b)   { public_collection(community.id) }
  let!(:sub_collection) { public_collection(collection_a.id) }
  let!(:work_a)         { public_work(collection_a.id) }
  let!(:work_sub)       { public_work(sub_collection.id) }
  let!(:work_b)         { public_work(collection_b.id) }

  # Anonymous (public-only) discovery context, constructed the way the catalog
  # controller does (config.search_service_class = GatedSearchService).
  let(:user) { nil }
  let(:search_service) do
    GatedSearchService.new(config: CatalogController.blacklight_config, context: { current_user: user })
  end

  describe '.call' do
    it 'returns Works anywhere beneath the anchor, recursing nested collections' do
      ids = resolve(anchor: community)
      expect(ids).to contain_exactly(work_a.valkyrie_id, work_sub.valkyrie_id, work_b.valkyrie_id)
    end

    it 'scopes to a sub-tree, excluding sibling branches' do
      ids = resolve(anchor: collection_a)
      expect(ids).to contain_exactly(work_a.valkyrie_id, work_sub.valkyrie_id)
      expect(ids).not_to include(work_b.valkyrie_id)
    end

    it 'excludes the anchor\'s own direct members when include_self is false' do
      ids = resolve(anchor: collection_a, include_self: false)
      expect(ids).to contain_exactly(work_sub.valkyrie_id)
    end

    context 'with the linked-member (DAG) overlay' do
      before { AtlasRb::Work.add_linked_member(work_b.id, collection_a.id, nuid: nuid) }
      after  { AtlasRb::Work.remove_linked_member(work_b.id, collection_a.id, nuid: nuid) }

      it 'surfaces Works linked into the sub-tree when include_linked is true' do
        expect(resolve(anchor: collection_a, include_linked: true)).to include(work_b.valkyrie_id)
      end

      it 'ignores linked Works when include_linked is false' do
        expect(resolve(anchor: collection_a, include_linked: false)).not_to include(work_b.valkyrie_id)
      end
    end

    it 'applies gated discovery — a non-public Work is hidden from an anonymous user' do
      restricted = AtlasRb::Work.create(collection_a.id, mods('work'), nuid: nuid)
      AtlasRb::Work.complete(restricted.id, nuid: nuid)
      AtlasRb::Work.metadata(restricted.id,
                             { 'permissions' => { 'read' => ['northeastern:drs:repository:staff'] } },
                             nuid: nuid)

      expect(resolve(anchor: collection_a)).not_to include(restricted.valkyrie_id)
    end

    it 'returns an empty response for a blank anchor noid' do
      response = described_class.call(anchor_noid: '', search_service: search_service)
      expect(response.documents).to be_empty
    end

    it 'returns an empty response when nothing resolves beneath the anchor' do
      empty = public_collection(community.id)
      expect(resolve(anchor: empty)).to be_empty
    end
  end

  # --- helpers -------------------------------------------------------------

  def nuid = '000000004'
  def mods(kind) = "/home/cerberus/web/spec/fixtures/files/#{kind}-mods.xml"
  def read_public = { 'permissions' => { 'read' => ['public'] } }

  # Resolve and return the result document ids (uuids), passing the anchor's noid
  # (.id) and uuid (.valkyrie_id) the way a controller would.
  def resolve(anchor:, **opts)
    described_class.call(
      anchor_noid: anchor.id,
      anchor_uuid: anchor.valkyrie_id,
      search_service: search_service,
      **opts
    ).documents.map(&:id)
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

  def public_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Work.metadata(work.id, read_public, nuid: nuid)
    work
  end
end
