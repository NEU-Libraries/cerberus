# frozen_string_literal: true

# Read-only model over the `impression_counts_by_day` TimescaleDB continuous
# aggregate (raw daily counts per noid/action — bots included, no rules). The
# "all traffic" side of the dashboard's human/bot toggle and the speed layer
# beneath it. Never written from Ruby (TimescaleDB maintains it).
class ImpressionCountByDay < ApplicationRecord
  self.table_name = 'impression_counts_by_day'
  self.primary_key = nil

  scope :in_range,   ->(range)  { where(day: range) }
  scope :for_action, ->(action) { where(action:) }

  def readonly? = true
end
