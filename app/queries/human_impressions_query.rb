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
  #
  # The offenders are an anti-join, not `NOT IN (subquery)`: Postgres hashes an
  # IN subquery only while it fits in work_mem, and past that reruns it for
  # every outer row. See docs/analytics.md.
  def from_where_sql
    <<~SQL.squish
      FROM impressions i
      LEFT JOIN user_agents ua ON ua.ua_string = i.user_agent
      LEFT JOIN (#{volume_offenders_sql}) offender
        ON offender.ip_address = i.ip_address
       AND offender.day = #{ImpressionDay.of('i.created_at')}
      WHERE i.created_at >= #{@window_start}
        #{range_end_sql('i.')}
        AND i.ip_address IS NOT NULL
        AND COALESCE(ua.is_bot, FALSE) = FALSE
        AND (offender.ip_address IS NULL OR i.ip_address IN (#{allow_in}))
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
        SELECT ip_address, #{ImpressionDay.of('created_at')} AS day
        FROM impressions
        WHERE created_at >= #{@window_start}
          #{range_end_sql('')}
          AND ip_address IS NOT NULL
        GROUP BY ip_address, #{ImpressionDay.of('created_at')}
        HAVING count(*) > #{@threshold}
      SQL
    end
end
