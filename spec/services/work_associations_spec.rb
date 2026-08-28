# frozen_string_literal: true

require 'rails_helper'

# Builds real Works in Atlas, asserts real edges between them, then resolves
# those edges through the gated search. The point of the class is the gate, so
# the fixtures are real rather than stubbed: a stubbed Solr would prove only
# that the code calls the method it calls.
#
#   collection
#   ├── dataset        (public)   the Work under inspection
#   ├── codebook       (public)   asserts is_codebook_for → dataset
#   ├── figure         (public)   asserts is_figure_for   → dataset
#   └── secret         (staff)    asserts is_figure_for   → dataset
RSpec.describe WorkAssociations do
  before(:all) do
    @community  = public_community
    @collection = public_collection(@community.id)
    @dataset    = public_work(@collection.id)
    @codebook   = public_work(@collection.id)
    @figure     = public_work(@collection.id)
    @secret     = restricted_work(@collection.id)
  end

  let(:dataset)  { @dataset }
  let(:codebook) { @codebook }
  let(:figure)   { @figure }
  let(:secret)   { @secret }

  # nil = an anonymous visitor, who sees only what is public.
  #
  # `current_user:` goes in as a bare kwarg, not under `context:`.
  # Blacklight::SearchService#initialize collects `**context`, so a `context:`
  # kwarg nests one level deeper than SearchBuilder#gated_user looks — the
  # search then silently gates as anonymous, which passes any example that
  # only asserts something is hidden.
  let(:user) { nil }
  let(:search_service) do
    GatedSearchService.new(config:       CatalogController.blacklight_config,
                           search_state: Blacklight::SearchState.new({}, CatalogController.blacklight_config),
                           current_user: user)
  end

  def resolve(work_id)
    described_class.call(associations:   AtlasRb::Work.associations(work_id, nuid: nuid),
                         search_service: search_service)
  end

  def noids(documents) = documents.map(&:to_param)

  describe 'an unassociated Work' do
    it 'is empty, so the box renders nothing' do
      result = resolve(dataset.id)
      expect(result).to be_empty
      expect(result.size).to eq(0)
    end
  end

  context 'with edges in both directions' do
    before(:all) do
      AtlasRb::Work.associate(@codebook.id, @dataset.id, type: 'is_codebook_for', nuid: '000000004')
      AtlasRb::Work.associate(@figure.id, @dataset.id, type: 'is_figure_for', nuid: '000000004')
    end

    after(:all) do
      AtlasRb::Work.disassociate(@codebook.id, @dataset.id, type: 'is_codebook_for', nuid: '000000004')
      AtlasRb::Work.disassociate(@figure.id, @dataset.id, type: 'is_figure_for', nuid: '000000004')
    end

    # One stored edge, read from both ends: the codebook holds it, and the
    # dataset sees it derived. Neither end stores the other's view.
    it 'reads the asserting Work’s edge as outbound' do
      result = resolve(codebook.id)
      expect(noids(result.outbound.fetch('is_codebook_for'))).to eq([dataset.id])
      expect(result.inbound).to be_empty
    end

    it 'reads the same edge from the target as inbound' do
      result = resolve(dataset.id)
      expect(noids(result.inbound.fetch('is_codebook_for'))).to eq([codebook.id])
      expect(result.outbound).to be_empty
    end

    it 'groups the target’s edges by predicate' do
      expect(resolve(dataset.id).inbound.keys).to eq(%w[is_codebook_for is_figure_for])
    end

    # ASSOCIATION_TYPES order, not Atlas's hash order, so the box lists its
    # groups the same way on every Work.
    it 'orders the groups by the declared vocabulary, whatever order Atlas returns' do
      allow(AtlasRb::Work).to receive(:associations).and_return(
        'outbound' => { 'is_transcription_of' => [figure.id], 'is_codebook_for' => [codebook.id] },
        'inbound'  => {}
      )
      expect(resolve(dataset.id).outbound.keys).to eq(%w[is_codebook_for is_transcription_of])
    end
  end

  context 'when an edge points at a Work the viewer cannot read' do
    before(:all) do
      AtlasRb::Work.associate(@secret.id, @dataset.id, type: 'is_figure_for', nuid: '000000004')
    end

    after(:all) do
      AtlasRb::Work.disassociate(@secret.id, @dataset.id, type: 'is_figure_for', nuid: '000000004')
    end

    # Atlas's read floor is unconditional, so the endpoint reports this edge to
    # everybody. The gate is entirely Cerberus's here.
    it 'is reported by Atlas regardless of the viewer' do
      expect(AtlasRb::Work.associations(dataset.id, nuid: nuid).dig('inbound', 'is_figure_for'))
        .to include(secret.id)
    end

    # No row, and no group either — a bare "Figures" header with nothing under
    # it confirms that a record exists, which is what the gate exists to
    # prevent.
    it 'drops the row and the group it would have sat in' do
      result = resolve(dataset.id)
      expect(result).to be_empty
      expect(result.inbound).not_to have_key('is_figure_for')
    end

    it 'shows it to a staff viewer, who may read it' do
      staff = User.new(nuid: '000000006', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
      result = described_class.call(
        associations:   AtlasRb::Work.associations(dataset.id, nuid: nuid),
        search_service: GatedSearchService.new(config:       CatalogController.blacklight_config,
                                               search_state: Blacklight::SearchState.new({}, CatalogController.blacklight_config),
                                               current_user: staff)
      )
      expect(noids(result.inbound.fetch('is_figure_for'))).to include(secret.id)
    end
  end

  describe 'a malformed or absent reply' do
    # associations_or_none hands nil through when the Atlas read failed, so the
    # page renders without the box rather than 500ing.
    it 'treats nil as no associations' do
      expect(described_class.call(associations: nil, search_service: search_service)).to be_empty
    end

    it 'ignores a direction that is not a Hash' do
      result = described_class.call(associations:   { 'outbound' => nil, 'inbound' => [] },
                                    search_service: search_service)
      expect(result).to be_empty
    end

    # Atlas can add a sixth predicate before Cerberus knows it. An unknown token
    # is skipped here rather than rendered; the helper's humanized fallback
    # covers a token this class was taught about but the label table was not.
    it 'skips a predicate outside the known vocabulary' do
      result = described_class.call(associations:   { 'outbound' => { 'is_appendix_to' => [codebook.id] } },
                                    search_service: search_service)
      expect(result).to be_empty
    end
  end

  def nuid = '000000004'
  def mods(kind) = Rails.root.join('spec/fixtures/files', "#{kind}-mods.xml").to_s
  def read_public = { 'permissions' => { 'read' => ['public'] } }
  def read_staff  = { 'permissions' => { 'read' => ['northeastern:drs:repository:staff'] } }

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

  # Permissions are copied from the parent at create, so a child of the public
  # collection is born public and must be restricted explicitly.
  def restricted_work(parent_id)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Work.metadata(work.id, read_staff, nuid: nuid)
    work
  end
end
