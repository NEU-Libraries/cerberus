# frozen_string_literal: true

# Container-level human counts: per (container noid, action, day), summed down
# the structural-home tree from the leaf ImpressionDailyCount. Populated by
# RollupContainerImpressionsJob; powers top-N collections/communities (a trivial
# indexed ORDER BY, no derive-down at read time).
class ImpressionContainerDailyCount < ApplicationRecord
  self.table_name = 'impression_container_daily_counts'
  self.primary_key = nil

  scope :in_range,   ->(range)  { where(day: range) }
  scope :for_action, ->(action) { where(action:) }

  # Top-N container noids by total count over a range+action: [[noid, total], ...].
  def self.top(action:, range:, limit: 10)
    for_action(action).in_range(range)
                      .group(:noid).order(Arel.sql('SUM(count) DESC')).limit(limit)
                      .sum(:count).to_a
  end
end
