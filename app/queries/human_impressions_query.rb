# frozen_string_literal: true

# The "human" impressions filter: exclude known-bot user-agents, exclude
# volume-offending (ip, day) pairs, rescue the allowlist. A pure SQL-fragment
# builder with no reads or writes of its own. See docs/analytics.md.
class HumanImpressionsQuery
  # `range_end` nil means an open-ended trailing window; `noids` nil means
  # every noid. Both are the repo-wide rollup's case.
  def initialize(conn:, window_start:, range_end: nil, noids: nil)
    @conn = conn
    @window_start = conn.quote(window_start)
    @range_end = range_end && conn.quote(range_end)
    @noids = noids
    @threshold = Integer(Rails.application.config.x.cerberus.impression_volume_threshold)
    @allowlist = Array(Rails.application.config.x.cerberus.impression_ip_allowlist)
  end

  # A fragment to append after the caller's own SELECT or aggregate. It
  # aliases the impressions table `i`.
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

    # Deliberately NEVER noid-scoped — an IP hammering many noids is still
    # abusive when the caller wants one noid, so scoping under-detects it. It
    # does respect the outer query's date window.
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
