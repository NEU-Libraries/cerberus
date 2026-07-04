# frozen_string_literal: true

require 'rails_helper'

# Builds a small hierarchy directly via AtlasRb (Atlas indexes synchronously,
# including ancestor_ids_ssim), then exercises the recipe resolver against it.
# The resolver only reads the three noid arrays off a compilation response, so
# recipes here are plain hashes — the Compilation endpoints themselves are
# exercised by the sets request spec.
#
#   community
#   ├── collection_a
#   │   ├── work_a            (home)
#   │   └── sub_collection
#   │       └── work_sub      (home)
#   └── collection_b
#       ├── work_b            (home)
#       └── work_c            (home)
RSpec.describe SetResolver do
  let!(:community)      { public_community }
  let!(:collection_a)   { public_collection(community.id) }
  let!(:collection_b)   { public_collection(community.id) }
  let!(:sub_collection) { public_collection(collection_a.id) }
  let!(:work_a)         { public_work(collection_a.id) }
  let!(:work_sub)       { public_work(sub_collection.id) }
  let!(:work_b)         { public_work(collection_b.id) }
  let!(:work_c)         { public_work(collection_b.id) }

  let(:user) { nil }
  let(:search_service) do
    GatedSearchService.new(config: CatalogController.blacklight_config, context: { current_user: user })
  end

  describe '#contents_fqs' do
    it 'resolves an included collection transitively, through nested sub-collections' do
      expect(contents(recipe(collections: [collection_a])))
        .to contain_exactly(work_a.valkyrie_id, work_sub.valkyrie_id)
    end

    it 'unions individually-added works with collection contents' do
      expect(contents(recipe(collections: [collection_a], works: [work_b])))
        .to contain_exactly(work_a.valkyrie_id, work_sub.valkyrie_id, work_b.valkyrie_id)
    end

    it 'subtracts set-aside works from an included collection' do
      expect(contents(recipe(collections: [collection_a], exclusions: [work_sub])))
        .to contain_exactly(work_a.valkyrie_id)
    end

    it 'subtracts a set-aside that was individually added' do
      expect(contents(recipe(works: [work_b, work_c], exclusions: [work_c])))
        .to contain_exactly(work_b.valkyrie_id)
    end

    it 'deduplicates a work reachable via a collection and a direct add' do
      expect(contents(recipe(collections: [collection_a], works: [work_a])))
        .to contain_exactly(work_a.valkyrie_id, work_sub.valkyrie_id)
    end

    it 'is nil for an empty recipe (a new Set renders empty, not the whole index)' do
      expect(resolver(recipe).contents_fqs).to be_nil
    end

    it 'is nil when the only recipe nouns are exclusions' do
      expect(resolver(recipe(exclusions: [work_a])).contents_fqs).to be_nil
    end

    it 'applies gated discovery to the contents' do
      restricted = restricted_work(collection_a.id)
      expect(contents(recipe(collections: [collection_a]))).not_to include(restricted.valkyrie_id)
    end

    context 'with the linked-member (DAG) overlay' do
      before { AtlasRb::Work.add_linked_member(work_b.id, collection_a.id, nuid: nuid) }
      after  { AtlasRb::Work.remove_linked_member(work_b.id, collection_a.id, nuid: nuid) }

      it 'includes works linked into an included collection' do
        expect(contents(recipe(collections: [collection_a]))).to include(work_b.valkyrie_id)
      end
    end
  end

  describe '#chips' do
    it 'tallies live and total per included collection, in recipe order' do
      chips = resolver(recipe(collections: [collection_a, collection_b])).chips
      expect(chips.map(&:noid)).to eq([collection_a.id, collection_b.id])
      expect(chips.map(&:total)).to eq([2, 2])
      expect(chips.map(&:live)).to eq([2, 2])
    end

    it 'diverges live from total when a set-aside overlaps the chip' do
      chips = resolver(recipe(collections: [collection_a, collection_b], exclusions: [work_sub])).chips
      a = chips.find { |c| c.noid == collection_a.id }
      b = chips.find { |c| c.noid == collection_b.id }
      expect([a.live, a.total]).to eq([1, 2])
      expect([b.live, b.total]).to eq([2, 2])
    end

    it 'omits a chip the user cannot discover' do
      hidden = restricted_collection(community.id)
      chips = resolver(recipe(collections: [hidden, collection_b])).chips
      expect(chips.map(&:noid)).to eq([collection_b.id])
    end
  end

  describe '#provenance_for' do
    it 'attributes a direct add, a collection member, and a nested member' do
      res = resolver(recipe(collections: [collection_a], works: [work_b]))
      docs = contents_documents(res)

      expect(res.provenance_for(doc(docs, work_b))).to eq(:direct)
      expect(res.provenance_for(doc(docs, work_a))).to eq(collection_a.id)
      expect(res.provenance_for(doc(docs, work_sub))).to eq(collection_a.id)
    end

    it 'prefers direct over via-collection when both apply' do
      res = resolver(recipe(collections: [collection_a], works: [work_a]))
      docs = contents_documents(res)
      expect(res.provenance_for(doc(docs, work_a))).to eq(:direct)
    end
  end

  describe '#aside_documents' do
    it 'returns the set-aside works as gated documents' do
      res = resolver(recipe(collections: [collection_a], exclusions: [work_sub]))
      expect(res.aside_documents.map(&:id)).to contain_exactly(work_sub.valkyrie_id)
    end

    it 'is empty when nothing is set aside' do
      expect(resolver(recipe(collections: [collection_a])).aside_documents).to be_empty
    end
  end

  describe '#each_content_batch' do
    def batched_ids(compilation, **opts)
      ids = []
      resolver(compilation).each_content_batch(**opts) { |docs| ids.concat(docs.map(&:id)) }
      ids
    end

    it 'yields the gated content works of the recipe (collection ∪ added work)' do
      expect(batched_ids(recipe(collections: [collection_a], works: [work_b])))
        .to contain_exactly(work_a.valkyrie_id, work_sub.valkyrie_id, work_b.valkyrie_id)
    end

    it 'pages through in batches, yielding every work across pages' do
      expect(batched_ids(recipe(collections: [collection_a]), batch: 1))
        .to contain_exactly(work_a.valkyrie_id, work_sub.valkyrie_id)
    end

    it 'applies gated discovery — a restricted work is never yielded' do
      restricted = restricted_work(collection_a.id)
      expect(batched_ids(recipe(collections: [collection_a]))).not_to include(restricted.valkyrie_id)
    end

    it 'does not yield at all for an empty recipe' do
      yielded = false
      resolver(recipe).each_content_batch { |_docs| yielded = true }
      expect(yielded).to be(false)
    end

    it 'yields docs carrying the noid in alternate_ids_ssim (the packer keys folders/files on it)' do
      docs = []
      resolver(recipe(works: [work_a])).each_content_batch { |batch| docs.concat(batch) }
      noids = docs.map { |d| Array(d['alternate_ids_ssim']).first.to_s.delete_prefix('id-') }
      expect(noids).to include(work_a.id)
    end
  end

  # --- helpers -------------------------------------------------------------

  def nuid = '000000004'
  def mods(kind) = "/home/cerberus/web/spec/fixtures/files/#{kind}-mods.xml"
  def read_public = { 'permissions' => { 'read' => ['public'] } }
  def read_staff  = { 'permissions' => { 'read' => ['northeastern:drs:repository:staff'] } }

  def recipe(collections: [], works: [], exclusions: [])
    { 'included_collections' => collections.map(&:id),
      'included_works'       => works.map(&:id),
      'excluded_works'       => exclusions.map(&:id) }
  end

  def resolver(compilation)
    described_class.new(compilation: compilation, search_service: search_service)
  end

  # Run the contents search the way SetsController does: the resolver's fqs on
  # a state-seeded builder.
  def contents_documents(res)
    fqs = res.contents_fqs
    return [] if fqs.nil?

    builder = search_service.search_builder.with({}).with_filters(*fqs)
    Blacklight.default_index.search(builder).documents
  end

  def contents(compilation)
    contents_documents(resolver(compilation)).map(&:id)
  end

  def doc(docs, resource)
    docs.find { |d| d.id == resource.valkyrie_id } or raise "doc for #{resource.id} not in contents"
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

  # Permissions are copied from the parent at create (a child of the public
  # community is born public), so restriction must be written explicitly.
  def restricted_collection(parent_id)
    collection = AtlasRb::Collection.create(parent_id, mods('collection'), nuid: nuid)
    AtlasRb::Collection.metadata(collection.id, read_staff, nuid: nuid)
    collection
  end

  def public_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Work.metadata(work.id, read_public, nuid: nuid)
    work
  end

  def restricted_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Work.metadata(work.id, read_staff, nuid: nuid)
    work
  end
end
