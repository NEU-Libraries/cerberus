# frozen_string_literal: true

# Assembles the /admin impressions dashboard from the derived rollups (never raw
# rows, except for a scoped unique-visitors read — see below). The human/bot
# segment toggle picks the source: :human reads the derived ImpressionDailyCount
# (bots/volume filtered), :all reads the ImpressionCountByDay continuous
# aggregate (raw counts). Container top-N always reads the human container
# rollup (no all-traffic container layer exists). Leaf rows are keyed by any
# resource noid (views are recorded on Work/Collection/Community show pages),
# so "top files" filters to Works by resolving types from Solr.
#
# An optional ImpressionScope (item picker and/or Content/Featured-Content
# facet) narrows every metric to its resolved noid set. Unique visitors has no
# per-noid rollup table at all (ImpressionDailyVisitor is repo-wide by
# design — distinct IPs can't be summed across a noid subset from a
# pre-aggregated total), so a scoped view computes it live from raw
# `impressions` via HumanImpressionsQuery instead of waiting on a rollup that
# was never going to exist for this shape.
class ImpressionsReport
  ACTIONS      = %w[view download].freeze # stream deferred (no Range endpoint)
  DEFAULT_DAYS = 90
  TOP_LIMIT    = 10
  TITLE_FIELD  = 'title_tsim'

  attr_reader :range, :segment, :scope

  def initialize(range: nil, segment: :human, scope: nil)
    @range   = range || (DEFAULT_DAYS.days.ago.to_date..Date.current)
    @segment = segment.to_s == 'all' ? :all : :human
    @scope   = scope
  end

  def scoped?
    @scope&.active? || false
  end

  # Whether the "Top collections" tab applies — always true when unscoped
  # (repo-wide), deferring to the scope's own rule otherwise (a facet or a
  # single-Work scope has no sub-collections concept).
  def show_collections_tab?
    !scoped? || scope.show_collections_tab?
  end

  # { action => grand total } over the range.
  def totals
    ACTIONS.index_with { |action| series(action).values.sum }
  end

  # chartkick-ready { day => count } for one action, honouring the segment
  # and any active scope.
  def series(action)
    scoped_leaf = leaf.for_action(action).in_range(range)
    scoped_leaf = scoped_leaf.where(noid: scope.overview_noids) if scoped?
    scoped_leaf.group(:day).order(:day).sum(sum_column)
  end

  # { day => unique non-bot visitors } (human only; §10) — repo-wide rollup
  # when unscoped, a live raw-table read (honouring the segment) when scoped.
  def unique_visitors_series
    return ImpressionDailyVisitor.series(range:) unless scoped?

    ScopedVisitorsQuery.new(range:, segment:, noids: scope.overview_noids).series
  end

  # Top Works by total usage: [{ noid:, doc:, counts: { 'view' => n, ... }, total: }].
  def top_works(limit: TOP_LIMIT)
    typed_top(limit:, types: %w[Work], restrict_noids: scoped? ? scope.top_works_noids : nil)
  end

  # Top containers by total usage, from the derive-down rollup. Not applicable
  # once a facet is active, or when scoped to a single Work — see
  # ImpressionScope#show_collections_tab?.
  def top_containers(limit: TOP_LIMIT)
    return [] if scoped? && !scope.show_collections_tab?

    restrict = scoped? ? scope.top_containers_noids : nil
    base = ImpressionContainerDailyCount.in_range(range)
    base = base.where(noid: restrict) if restrict
    rows = base.group(:noid).order(total_desc).limit(limit).sum(:count)
    breakdown = ImpressionContainerDailyCount.in_range(range).where(noid: rows.keys)
                                             .group(:noid, :action).sum(:count)
    rows_for(rows.keys, breakdown)
  end

  private

    def leaf
      @segment == :all ? ImpressionCountByDay : ImpressionDailyCount
    end

    def sum_column
      @segment == :all ? :impressions : :count
    end

    def total_desc
      Arel.sql('SUM(count) DESC')
    end

    # Top leaf noids by total, filtered to the given Solr resource types and
    # (when scoped) pre-restricted to restrict_noids before ranking.
    def typed_top(limit:, types:, restrict_noids: nil)
      base = leaf.in_range(range)
      base = base.where(noid: restrict_noids) if restrict_noids
      ranked = base.group(:noid)
                   .order(Arel.sql("SUM(#{sum_column}) DESC")).limit(limit * 5)
                   .sum(sum_column)
      docs = resolve(ranked.keys)
      typed = ranked.keys.select { |noid| types.include?(type_of(docs[noid])) }.first(limit)
      breakdown = leaf.in_range(range).where(noid: typed).group(:noid, :action).sum(sum_column)
      rows_for(typed, breakdown, docs)
    end

    # Build display rows for an ordered noid list + a {[noid, action] => n} breakdown.
    def rows_for(noids, breakdown, docs = nil)
      docs ||= resolve(noids)
      noids.map do |noid|
        counts = ACTIONS.index_with { |action| breakdown[[noid, action]].to_i }
        { noid:, doc: docs[noid], counts:, total: counts.values.sum }
      end
    end

    # noid => SolrDocument (system-wide; no gated discovery — analytics).
    def resolve(noids)
      return {} if noids.empty?

      terms = noids.map { |noid| "id-#{noid}" }.join(',')
      Blacklight.default_index.search(
        q: '*:*', fq: ["{!terms f=alternate_ids_ssim}#{terms}"],
        rows: noids.size, fl: "id,alternate_ids_ssim,internal_resource_tesim,#{TITLE_FIELD}"
      ).documents.index_by { |doc| Array(doc['alternate_ids_ssim']).first&.delete_prefix('id-') }
    end

    def type_of(doc)
      doc && Array(doc['internal_resource_tesim']).first
    end
end
