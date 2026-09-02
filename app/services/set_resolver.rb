# frozen_string_literal: true

# Resolves a Set's (Compilation's) recipe against Solr into its contents.
# Every query here runs through the gated SearchBuilder chain, so a restricted
# recipe noun stays invisible to a user who may not discover it.
# See docs/sets.md.
class SetResolver
  DEFAULT_TYPE_FILTERS = [
    'internal_resource_tesim:Work',
    '-tombstoned_bsi:true'
  ].freeze

  MAX_EXPORT_ROWS = 10_000

  # The UNION of both packers' fields, asked of them rather than listed here:
  # a field one packer needs and this list omits reads nil on every document,
  # silently, and that failure serves content it should withhold.
  PACKER_FIELDS = (SetZipPacker::REQUIRED_DOC_FIELDS | MetadataExportPacker::REQUIRED_DOC_FIELDS).join(',')

  Chip = Struct.new(:noid, :uuid, :live, :total, keyword_init: true)

  def initialize(compilation:, search_service:)
    @compilation = compilation
    @search_service = search_service
  end

  # nil, never [], when the recipe has no positive clause: a Set with no fq at
  # all matches the whole index instead of rendering empty.
  def contents_fqs
    return nil if positive_clauses.empty?

    fqs = [MembershipQuery.any_of(positive_clauses)]
    fqs << MembershipQuery.excluding_fq(MembershipQuery.identity_fq(excluded_uuids)) if excluded_uuids.any?
    fqs + DEFAULT_TYPE_FILTERS
  end

  def contents_count
    fqs = contents_fqs
    return 0 if fqs.nil?

    search(*fqs, rows: 0).total
  end

  # The *same* gated contents search the show page runs, so a viewer exports
  # only what they can discover. Discovery is not the whole rule: an embargoed
  # Work is discoverable, and the packer withholds it using PACKER_FIELDS.
  def each_content_batch(batch: 200)
    fqs = contents_fqs
    return if fqs.nil?

    start = 0
    loop do
      docs = search(*fqs, rows: batch, start: start, fl: PACKER_FIELDS).documents
      break if docs.empty?

      yield docs
      start += docs.size
      break if start >= MAX_EXPORT_ROWS
    end
  end

  def chips
    @chips ||= collection_uuids.map do |noid, uuid|
      total = count(MembershipQuery.members_fq(container_sets[noid].to_a, include_linked: true))
      Chip.new(noid: noid, uuid: uuid, live: total - excluded_overlap(noid), total: total)
    end
  end

  def provenance_for(document)
    return :direct if included_work_uuids.include?(document.id)

    edges = membership_edges(document)
    chips.find { |chip| edges.intersect?(container_sets[chip.noid]) }&.noid
  end

  def aside_documents
    return [] if excluded_uuids.empty?

    @aside_documents ||= search(MembershipQuery.identity_fq(excluded_uuids),
                                *DEFAULT_TYPE_FILTERS).documents
  end

  private

    # ---- recipe-noun resolution (noid → uuid, gated) ----------------------

    # Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
    def noun_uuids
      @noun_uuids ||= begin
        noids = recipe_collections + recipe_works + recipe_exclusions
        if noids.empty?
          {}
        else
          docs = search("{!terms f=alternate_ids_ssim}#{noids.map { |n| "id-#{n}" }.join(',')}",
                        rows: noids.size, fl: 'id,alternate_ids_ssim').documents
          docs.to_h { |doc| [Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-'), doc.id] }
        end
      end
    end

    def collection_uuids
      @collection_uuids ||= recipe_collections.filter_map do |noid|
        uuid = noun_uuids[noid]
        [noid, uuid] if uuid
      end
    end

    def included_work_uuids
      @included_work_uuids ||= recipe_works.filter_map { |noid| noun_uuids[noid] }.to_set
    end

    def excluded_uuids
      @excluded_uuids ||= recipe_exclusions.filter_map { |noid| noun_uuids[noid] }
    end

    def recipe_collections = Array(@compilation['included_collections'])
    def recipe_works       = Array(@compilation['included_works'])
    def recipe_exclusions  = Array(@compilation['excluded_works'])

    # ---- descendant containers (step 1, one query for all chips) -----------

    def container_sets
      @container_sets ||= begin
        sets = collection_uuids.to_h { |noid, uuid| [noid, Set[uuid]] }
        descendant_docs.each do |doc|
          Array(doc['ancestor_ids_ssim']).each { |noid| sets[noid]&.add(doc.id) }
        end
        sets
      end
    end

    def descendant_docs
      return [] if collection_uuids.empty?

      search(MembershipQuery.descendants_fq(collection_uuids.map(&:first)),
             'internal_resource_tesim:(Collection OR Community)',
             rows: 100_000, fl: 'id,ancestor_ids_ssim').documents
    end

    # ---- contents clauses ---------------------------------------------------

    def positive_clauses
      @positive_clauses ||= begin
        containers = container_sets.values.reduce(Set.new, :|).to_a
        clauses = containers.any? ? MembershipQuery.member_clauses(containers, include_linked: true) : []
        clauses += [MembershipQuery.identity_fq(included_work_uuids.to_a)] if included_work_uuids.any?
        clauses
      end
    end

    def membership_edges(document)
      refs = Array(document['a_member_of_ssi']) + Array(document['a_linked_member_of_ssim'])
      refs.to_set { |ref| ref.to_s.delete_prefix('id-') }
    end

    # ---- per-chip tallies ---------------------------------------------------

    def excluded_overlap(noid)
      return 0 if excluded_uuids.empty?

      count(MembershipQuery.members_fq(container_sets[noid].to_a, include_linked: true),
            MembershipQuery.identity_fq(excluded_uuids))
    end

    def count(*filter_queries)
      search(*filter_queries, *DEFAULT_TYPE_FILTERS, rows: 0).total
    end

    # ---- plumbing -----------------------------------------------------------

    def search(*filter_queries, **extra)
      builder = @search_service.search_builder.with({}).with_filters(*filter_queries)
      builder = builder.merge(**extra) if extra.any?
      Blacklight.default_index.search(params: builder)
    end
end
