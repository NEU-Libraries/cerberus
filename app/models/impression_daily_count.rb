# frozen_string_literal: true

# The human-counts reporting target: per (noid, action, day) counts derived from
# raw impressions with the §9 rules applied (bot UAs excluded, volume-offending
# (ip,day) pairs excluded, allowlist rescued). Populated by RollupImpressionsJob;
# the dashboard's primary read.
class ImpressionDailyCount < ApplicationRecord
  self.table_name = 'impression_daily_counts'
  self.primary_key = nil

  scope :in_range,   ->(range)  { where(day: range) }
  scope :for_action, ->(action) { where(action:) }

  # Daily totals for one noid+action, as a chartkick-ready { day => count } hash.
  def self.series(noid:, action:, range:)
    for_action(action).in_range(range).where(noid:).order(:day).pluck(:day, :count).to_h
  end

  # Top-N noids by total count over a range+action: [[noid, total], ...].
  def self.top(action:, range:, limit: 10)
    for_action(action).in_range(range)
                      .group(:noid).order(Arel.sql('SUM(count) DESC')).limit(limit)
                      .sum(:count).to_a
  end
end
