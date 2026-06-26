# frozen_string_literal: true

# Repo-wide distinct-non-bot-IP count per day (§10 "unique visitors"). DISTINCT
# can't be summed across days, so the per-day figure is materialized at
# derivation time by RollupImpressionsJob. Also a bot-filter canary — an
# unexpected spike means a crawler is slipping past the filter.
class ImpressionDailyVisitor < ApplicationRecord
  self.table_name = 'impression_daily_visitors'
  self.primary_key = :day

  scope :in_range, ->(range) { where(day: range) }

  # chartkick-ready { day => unique_visitors } over a range.
  def self.series(range:)
    in_range(range).order(:day).pluck(:day, :unique_visitors).to_h
  end
end
