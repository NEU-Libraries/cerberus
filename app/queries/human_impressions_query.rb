# frozen_string_literal: true

# The "human" impressions filter (§9): exclude known-bot user-agents (the
# UserAgent dimension), exclude volume-offending (ip, day) pairs, rescue the
# allowlist. Shared by RollupImpressionsJob (repo-wide, persisted hourly) and
# ImpressionsReport's live scoped reads (a single item/facet's unique-visitor
# series can't wait for the next rollup and isn't worth persisting a table
# for). Pure SQL-fragment builder — no reads/writes of its own; callers
# interpolate `from_where_sql` after their own SELECT.
#
# Volume-offender detection is deliberately NEVER noid-scoped: an IP hammering
# the repo across many different noids is still abusive traffic even when the
# caller only wants one noid's numbers, so scoping would under-detect it.
class HumanImpressionsQuery
  # @param conn [ActiveRecord::ConnectionAdapters::AbstractAdapter] for quoting.
  # @param window_start [Time, ActiveSupport::TimeWithZone] earliest `created_at`.
  # @param range_end [Time, ActiveSupport::TimeWithZone, nil] exclusive upper
  #   bound on `created_at`, or nil for an open-ended trailing window (the
  #   repo-wide rollup's case — it only ever re-derives "since window_start").
  # @param noids [Array<String>, nil] restrict matched rows to these noids, or
  #   nil for every noid (also the repo-wide rollup's case).
  def initialize(conn:, window_start:, range_end: nil, noids: nil)
    @conn = conn
    @window_start = conn.quote(window_start)
    @range_end = range_end && conn.quote(range_end)
    @noids = noids
    @threshold = Integer(Rails.application.config.x.cerberus.impression_volume_threshold)
    @allowlist = Array(Rails.application.config.x.cerberus.impression_ip_allowlist)
  end

  # `FROM impressions i LEFT JOIN user_agents ... WHERE ...` — append after a
  # caller's own SELECT/aggregate. Aliases the impressions table `i`.
  def from_where_sql
    <<~SQL.squish
      FROM impressions i
      LEFT JOIN user_agents ua ON ua.ua_string = i.user_agent
      WHERE i.created_at >= #{@window_start}
        #{range_end_sql('i.')}
        AND COALESCE(ua.is_bot, FALSE) = FALSE
        AND NOT (
          i.ip_address NOT IN (#{allow_in})
          AND (i.ip_address, i.created_at::date) IN (#{volume_offenders_sql})
        )
        #{noid_filter_sql}
    SQL
  end

  private

    def allow_in
      @allowlist.empty? ? "''" : @allowlist.map { |ip| @conn.quote(ip) }.join(', ')
    end

    def range_end_sql(prefix)
      return '' unless @range_end

      "AND #{prefix}created_at < #{@range_end}"
    end

    def noid_filter_sql
      return '' if @noids.nil?
      return 'AND FALSE' if @noids.empty?

      "AND i.noid IN (#{@noids.map { |n| @conn.quote(n) }.join(', ')})"
    end

    # Volume-offender detection never takes the noid filter (see class doc)
    # but does respect the same date window as the outer query.
    def volume_offenders_sql
      <<~SQL.squish
        SELECT ip_address, created_at::date
        FROM impressions
        WHERE created_at >= #{@window_start}
          #{range_end_sql('')}
          AND ip_address IS NOT NULL
        GROUP BY ip_address, created_at::date
        HAVING count(*) > #{@threshold}
      SQL
    end
end
