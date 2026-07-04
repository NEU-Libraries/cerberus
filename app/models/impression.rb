# frozen_string_literal: true

# A single, immutable, append-only usage event (a view/download/stream of a
# repository object), stored in Cerberus's primary DB as a TimescaleDB
# hypertable. Bot classification is *never* written here — it is derived later
# from the UserAgent dimension + the runtime rules (see the design). Rows are
# only ever inserted, never updated or destroyed.
class Impression < ApplicationRecord
  ACTIONS = %w[view download stream].freeze

  THROTTLE_WINDOW = 1.hour

  # Presence is scoped to the event-identity triple that the dedup throttle
  # keys on — not v1's all-seven-columns rule, which would drop legitimate
  # traffic from privacy clients that suppress Referer or send no User-Agent.
  # session_id / referrer / user_agent are descriptive and nullable.
  validates :noid, :action, :ip_address, presence: true
  validates :action, inclusion: { in: ACTIONS }
  validate :within_throttle_window, on: :create

  private

    # Suppress refresh-spam: at most one (noid, action, ip_address) row per hour.
    # Backed by the (noid, action, ip_address, created_at) index as a bounded
    # EXISTS — it never loads matching rows into memory (v1's mistake). Runs in
    # RecordImpressionJob, off the request thread.
    def within_throttle_window
      return if noid.blank? || action.blank? || ip_address.blank?

      duplicate = Impression
                  .where(noid:, action:, ip_address:)
                  .exists?(created_at: THROTTLE_WINDOW.ago..)

      errors.add(:base, 'throttled within the hour') if duplicate
    end
end
