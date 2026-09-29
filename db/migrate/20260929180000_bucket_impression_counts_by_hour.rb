# frozen_string_literal: true

# Rebuilds the raw-counts continuous aggregate on 1-hour buckets, so the report
# can fold them into Eastern days. `created_at` is a UTC `timestamp`, and a
# continuous aggregate can only bucket it at a fixed offset, which is wrong for
# part of every year once daylight saving shifts. Eastern offsets are whole
# hours, so hourly buckets fold into Eastern days exactly. See docs/analytics.md.
class BucketImpressionCountsByHour < ActiveRecord::Migration[8.1]
  # CREATE MATERIALIZED VIEW ... WITH (timescaledb.continuous), its refresh
  # policy and refresh_continuous_aggregate cannot run inside a transaction.
  disable_ddl_transaction!

  REFRESH_POLICIES = {
    start_offset:      "INTERVAL '7 days'",
    end_offset:        "INTERVAL '1 hour'",
    schedule_interval: "INTERVAL '1 hour'"
  }.freeze

  def up
    drop_continuous_aggregates(:impression_counts_by_day)
    create_continuous_aggregate(:impression_counts_by_day, <<~SQL.squish, refresh_policies: REFRESH_POLICIES)
      SELECT noid,
             action,
             time_bucket('1 hour', created_at) AS hour,
             count(*) AS impressions
      FROM impressions
      GROUP BY noid, action, hour
    SQL
    # The policy only re-materializes its last 7 days; without this, older
    # history would vanish from the "All traffic" segment.
    execute "CALL refresh_continuous_aggregate('impression_counts_by_day', NULL, NULL)"
  end

  def down
    drop_continuous_aggregates(:impression_counts_by_day)
    create_continuous_aggregate(:impression_counts_by_day, <<~SQL.squish, refresh_policies: REFRESH_POLICIES)
      SELECT noid,
             action,
             time_bucket('1 day', created_at) AS day,
             count(*) AS impressions
      FROM impressions
      GROUP BY noid, action, day
    SQL
    execute "CALL refresh_continuous_aggregate('impression_counts_by_day', NULL, NULL)"
  end
end
