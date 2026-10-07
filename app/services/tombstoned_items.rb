# frozen_string_literal: true

# Lists every tombstoned (withdrawn) top-level resource — Works, Collections
# and Communities — for the admin tombstone registry: paginated, filterable by
# withdrawal date, and searchable by title or PID. A search that matches a
# container also lists the container's tombstoned descendants, because purging
# a container means purging what it holds first. See docs/admin.md.
class TombstonedItems < ApplicationService
  PER_PAGE_OPTIONS = [10, 20, 50, 100].freeze
  DEFAULT_PER_PAGE = 50

  # A search's own matches are capped before their descendants are read, so a
  # broad query cannot fan out into thousands of identity terms.
  MATCH_LIMIT = 500
  DESCENDANT_LIMIT = 10_000

  CONTAINERS = %w[Collection Community].freeze
  TYPE_FILTER = 'internal_resource_tesim:(Work OR Collection OR Community)'
  DATE_FIELD = 'tombstoned_at_dtsi'

  # @param scope [#blacklight_config, #current_user] the admin controller.
  # @param page [Integer, String, nil] 1-based page number.
  # @param query [String, nil] words to search titles and PIDs by.
  # @param per_page [Integer, String, nil] one of PER_PAGE_OPTIONS.
  # @param from [Date, nil] earliest withdrawal date, inclusive.
  # @param to [Date, nil] latest withdrawal date, inclusive.
  def initialize(scope:, page: nil, query: nil, per_page: nil, from: nil, to: nil)
    @scope = scope
    @page = page
    @query = query.to_s.strip.presence
    @per_page = PER_PAGE_OPTIONS.include?(per_page.to_i) ? per_page.to_i : DEFAULT_PER_PAGE
    @from = from
    @to = to
    super()
  end

  # @return [Blacklight::Solr::Response] most recently withdrawn first; a plain
  #   search with no descendants to add ranks by relevance instead.
  def call
    identities = identity_listing
    by_date = identities || @query.nil?
    builder = TombstonedSearchBuilder.new(@scope).with(q: by_date ? '*:*' : @query, per_page: @per_page, page: @page)
                                     .with_filters(*filters(identities))
    builder = builder.merge(sort: "#{DATE_FIELD} desc") if by_date
    Blacklight.default_index.search(params: builder)
  end

  private

    # A search that matched containers lists by identity: its own matches plus
    # their tombstoned descendants. nil when there is nothing to add.
    def identity_listing
      return if @query.nil?

      descendants = descendant_ids(matches)
      matches.map(&:id) + descendants if descendants.any?
    end

    def filters(identities)
      [date_filter, (MembershipQuery.identity_fq(identities) if identities)].compact
    end

    # The search's own matches, within the date range.
    def matches
      @matches ||= begin
        builder = TombstonedSearchBuilder.new(@scope).with(q: @query, per_page: MATCH_LIMIT)
                                         .with_filters(*[date_filter].compact)
                                         .merge(fl: 'id,internal_resource_tesim,alternate_ids_ssim')
        Blacklight.default_index.search(params: builder).documents
      end
    end

    # Two reads, because only containers carry ancestor_ids_ssim: first every
    # container beneath the matched ones, then the members of all of them.
    # The ancestor values are bare NOIDs; the structural parent is `id-<uuid>`.
    def descendant_ids(matched)
      containers = matched.select { |doc| CONTAINERS.include?(doc.klass_type) }
      return [] if containers.empty?

      noids = containers.map { |doc| Array(doc['alternate_ids_ssim']).first.to_s.delete_prefix('id-') }
      nested = tombstoned_ids("{!terms f=ancestor_ids_ssim}#{noids.join(',')}")
      parents = (containers.map(&:id) + nested).map { |uuid| "id-#{uuid}" }
      members = tombstoned_ids("{!terms f=#{MembershipQuery::STRUCTURAL_FIELD}}#{parents.join(',')}")
      (nested + members).uniq
    end

    # FileSets share the structural parent field, so the type filter keeps them
    # out of the identity list.
    def tombstoned_ids(filter)
      Blacklight.default_index.search(q: '*:*', rows: DESCENDANT_LIMIT, fl: 'id',
                                      fq: ['tombstoned_bsi:true', TYPE_FILTER, filter]).documents.map(&:id)
    end

    # Whole UTC days: the upper bound is the day after `to`, exclusive, so `to`
    # is inclusive.
    def date_filter
      return if @from.nil? && @to.nil?

      lower = @from ? "#{@from.iso8601}T00:00:00Z" : '*'
      upper = @to ? "#{(@to + 1).iso8601}T00:00:00Z" : '*'
      "#{DATE_FIELD}:[#{lower} TO #{upper}}"
    end
end
