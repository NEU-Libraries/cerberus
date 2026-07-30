# frozen_string_literal: true

# Derives the HUMAN-counts reporting layer from raw impressions, applying the §9
# rules a continuous aggregate can't (they must filter BEFORE aggregating by
# noid) via HumanImpressionsQuery: exclude bot user-agents (UA dimension),
# exclude volume-offending (ip, day) pairs (> threshold/day), rescue the
# allowlist IP. Re-derives a trailing window each run (idempotent
# delete+insert), so a bot-list change (via ReclassifyUserAgentsJob) is
# reflected at the next run. Also materializes the per-day distinct-human-IP
# "unique visitors" metric (§10). Scheduled hourly.
class RollupImpressionsJob < ApplicationJob
  queue_as :background

  WINDOW = 90.days

  def perform(window: WINDOW)
    conn = ActiveRecord::Base.connection
    raw_window_start = window.ago.beginning_of_day
    window_start = conn.quote(raw_window_start)
    human = HumanImpressionsQuery.new(conn:, window_start: raw_window_start).from_where_sql

    conn.transaction do
      rebuild_daily_counts(conn, window_start, human)
      rebuild_daily_visitors(conn, window_start, human)
    end
  end

  private

    def rebuild_daily_counts(conn, window_start, human)
      conn.execute("DELETE FROM impression_daily_counts WHERE day >= #{window_start}::date")
      conn.execute(<<~SQL.squish)
        INSERT INTO impression_daily_counts (noid, action, day, count)
        SELECT i.noid, i.action, i.created_at::date AS day, count(*) AS count
        #{human}
        GROUP BY i.noid, i.action, i.created_at::date
      SQL
    end

    def rebuild_daily_visitors(conn, window_start, human)
      conn.execute("DELETE FROM impression_daily_visitors WHERE day >= #{window_start}::date")
      conn.execute(<<~SQL.squish)
        INSERT INTO impression_daily_visitors (day, unique_visitors)
        SELECT i.created_at::date AS day, count(DISTINCT i.ip_address) AS unique_visitors
        #{human}
        GROUP BY i.created_at::date
      SQL
    end
end
