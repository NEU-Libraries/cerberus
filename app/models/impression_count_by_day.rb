# frozen_string_literal: true

# Read-only model over the `impression_counts_by_day` TimescaleDB continuous
# aggregate (raw counts per noid/action — bots included, no rules). The
# "all traffic" side of the dashboard's human/bot toggle and the speed layer
# beneath it. Never written from Ruby (TimescaleDB maintains it).
#
# Its buckets are UTC hours, not days: read it by Eastern day through
# `in_range` and `day_sql`, never by `hour` directly. See docs/analytics.md.
class ImpressionCountByDay < ApplicationRecord
  self.table_name = 'impression_counts_by_day'
  self.primary_key = nil

  scope :in_range,   ->(range)  { where(hour: ImpressionDay.utc_bounds(range)) }
  scope :for_action, ->(action) { where(action:) }

  # The Eastern day an hourly bucket falls in.
  def self.day_sql = Arel.sql(ImpressionDay.of('hour'))

  def readonly? = true
end
