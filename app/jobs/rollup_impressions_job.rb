# frozen_string_literal: true

# Derives the HUMAN-counts reporting layer from raw impressions, applying the §9
# rules a continuous aggregate can't (they must filter BEFORE aggregating by
# noid): exclude bot user-agents (UA dimension), exclude volume-offending
# (ip, day) pairs (> threshold/day), rescue the allowlist IP. Re-derives a
# trailing window each run (idempotent delete+insert), so a bot-list change (via
# ReclassifyUserAgentsJob) is reflected at the next run. Also materializes the
# per-day distinct-human-IP "unique visitors" metric (§10). Scheduled hourly.
class RollupImpressionsJob < ApplicationJob
  queue_as :background

  WINDOW = 90.days

  def perform(window: WINDOW)
    conn = ActiveRecord::Base.connection
    window_start = conn.quote(window.ago.beginning_of_day)
    human = human_scope_sql(conn, window_start)

    conn.transaction do
      conn.execute("DELETE FROM impression_daily_counts WHERE day >= #{window_start}::date")
      conn.execute(<<~SQL.squish)
        INSERT INTO impression_daily_counts (noid, action, day, count)
        SELECT i.noid, i.action, i.created_at::date AS day, count(*) AS count
        #{human}
        GROUP BY i.noid, i.action, i.created_at::date
      SQL

      conn.execute("DELETE FROM impression_daily_visitors WHERE day >= #{window_start}::date")
      conn.execute(<<~SQL.squish)
        INSERT INTO impression_daily_visitors (day, unique_visitors)
        SELECT i.created_at::date AS day, count(DISTINCT i.ip_address) AS unique_visitors
        #{human}
        GROUP BY i.created_at::date
      SQL
    end
  end

  private

  # The shared FROM/WHERE that selects only human rows in the window:
  #  - LEFT JOIN the UA dimension; keep rows whose UA is not a known bot
  #    (unknown/absent UA → not a bot → kept; the volume rule catches abusers).
  #  - drop (ip, day) pairs over the volume threshold, UNLESS the IP is allowlisted.
  def human_scope_sql(conn, window_start)
    threshold = Integer(Rails.application.config.x.cerberus.impression_volume_threshold)
    allowlist = Array(Rails.application.config.x.cerberus.impression_ip_allowlist)
    allow_in  = allowlist.empty? ? "''" : allowlist.map { |ip| conn.quote(ip) }.join(', ')

    <<~SQL.squish
      FROM impressions i
      LEFT JOIN user_agents ua ON ua.ua_string = i.user_agent
      WHERE i.created_at >= #{window_start}
        AND COALESCE(ua.is_bot, FALSE) = FALSE
        AND NOT (
          i.ip_address NOT IN (#{allow_in})
          AND (i.ip_address, i.created_at::date) IN (
            SELECT ip_address, created_at::date
            FROM impressions
            WHERE created_at >= #{window_start} AND ip_address IS NOT NULL
            GROUP BY ip_address, created_at::date
            HAVING count(*) > #{threshold}
          )
        )
    SQL
  end
end
