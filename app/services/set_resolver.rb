# frozen_string_literal: true

# Resolves a Set's (Compilation's) recipe against Solr: included collections
# (transitively, via a two-step reverse-ancestry recipe — find the descendant
# containers, then their member Works), plus individually-added Works, minus
# set-aside exclusions.
#
# The recipe arrives as the three noid lists off the AtlasRb::Compilation
# response (`included_collections` / `included_works` / `excluded_works`);
# everything else — uuid resolution, descendant lookup, the membership fq —
# is derived here from gated Solr queries, so a restricted recipe noun is
# silently invisible to a user who may not discover it. (Every step runs
# through the gated SearchBuilder chain; a future surface may want step 1
# ungated so a restricted intermediate container doesn't hide permitted Works
# beneath it — revisit if that need arises.)
#
# Not an ApplicationService: there is no single #call product. The resolver
# is instantiated once per render and read piecemeal — {#contents_fqs} for
# the controller to layer onto a builder seeded with the live search state
# (mirroring CatalogController#find_children), then the per-chip counts,
# provenance lookups, and aside-zone documents the Set page renders around
# the results. Every Solr round-trip is memoized on the instance.
class SetResolver
  # A Set's flat contents are leaf Works; intermediate containers are enumerated
  # during resolution but are not themselves "contents", so they're excluded.
  DEFAULT_TYPE_FILTERS = [
    'internal_resource_tesim:Work',
    '-tombstoned_bsi:true'
  ].freeze

  # One included collection, with its gated contents tally.
  # +live+ is what the Set currently shows from this collection; +total+ is
  # what it would show with nothing set aside. They diverge only when a
  # set-aside hole overlaps this collection ("4,998 of 5,000").
  Chip = Struct.new(:noid, :uuid, :live, :total, keyword_init: true)

  # @param compilation [#[]] the AtlasRb::Compilation response (carries the
  #   three bare-noid recipe arrays).
  # @param search_service [Blacklight::SearchService] supplies the gated search
  #   builder + index (typically the controller's `search_service`).
  def initialize(compilation:, search_service:)
    @compilation = compilation
    @search_service = search_service
  end

  # fq fragments for the contents search, or nil when the recipe has no
  # positive clause (a brand-new Set must render empty — no fq at all would
  # match the whole index).
  #
  # @return [Array<String>, nil]
  def contents_fqs
    return nil if positive_clauses.empty?

    fqs = [MembershipQuery.any_of(positive_clauses)]
    fqs << MembershipQuery.excluding_fq(MembershipQuery.identity_fq(excluded_uuids)) if excluded_uuids.any?
    fqs + DEFAULT_TYPE_FILTERS
  end

  # Gated tally of the Set's current contents (the index page's Works
  # column). Zero for a recipe with no positive clause.
  #
  # @return [Integer]
  def contents_count
    fqs = contents_fqs
    return 0 if fqs.nil?

    search(*fqs, rows: 0).total
  end

  # @return [Array<Chip>] one per included collection the current user can
  #   discover, in recipe order.
  def chips
    @chips ||= collection_uuids.map do |noid, uuid|
      total = count(MembershipQuery.members_fq(container_sets[noid].to_a, include_linked: true))
      Chip.new(noid: noid, uuid: uuid, live: total - excluded_overlap(noid), total: total)
    end
  end

  # Why a result row is in the Set: +:direct+ for an individually-added Work,
  # otherwise the noid of the first included collection whose subtree covers
  # one of the document's membership edges (nil when nothing matches — e.g. a
  # row reached via an edge the user cannot trace).
  #
  # @param document [SolrDocument]
  # @return [Symbol, String, nil]
  def provenance_for(document)
    return :direct if included_work_uuids.include?(document.id)

    edges = membership_edges(document)
    chips.find { |chip| edges.intersect?(container_sets[chip.noid]) }&.noid
  end

  # The set-aside Works, as gated Solr documents for the aside zone.
  # @return [Array<SolrDocument>]
  def aside_documents
    return [] if excluded_uuids.empty?

    @aside_documents ||= search(MembershipQuery.identity_fq(excluded_uuids),
                                *DEFAULT_TYPE_FILTERS).documents
  end

  private

    # ---- recipe-noun resolution (noid → uuid, gated) ----------------------

    # All three noid lists resolved to uuids in one gated lookup, keyed by
    # bare noid. Solr stores the noid in `alternate_ids_ssim` as `id-<noid>`.
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

    # Ordered [noid, uuid] pairs for the included collections the user can see.
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

    # Container uuids per chip noid: the chip itself plus every descendant
    # container whose ancestor chain names the chip. One reverse-ancestry
    # query covers all chips; each descendant doc self-reports which chips
    # cover it via its own `ancestor_ids_ssim`.
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

    # The document's outbound membership edges (structural parent + linked
    # overlay), as bare container uuids.
    def membership_edges(document)
      refs = Array(document['a_member_of_ssi']) + Array(document['a_linked_member_of_ssim'])
      refs.to_set { |ref| ref.to_s.delete_prefix('id-') }
    end

    # ---- per-chip tallies ---------------------------------------------------

    # How many of this chip's works are currently set aside (gated count).
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
      Blacklight.default_index.search(builder)
    end
end
