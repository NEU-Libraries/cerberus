# frozen_string_literal: true

# The user-agent dimension. Each distinct UA string is recorded once with a
# derived is_bot verdict, keyed by the string itself — so the table stays tiny
# (thousands of rows) regardless of impression volume, and a bot-list change is
# an O(distinct-UAs) re-scan rather than a rewrite of the raw log. This is the
# only place a bot verdict is materialized; raw impressions never carry one.
class UserAgent < ApplicationRecord
  self.primary_key = :ua_string

  # The current runtime bot substrings (ops-editable; see config/application.rb).
  def self.bot_substrings
    Rails.application.config.x.cerberus.impression_bots
  end

  # A UA is a bot when its lowercased string contains any current substring.
  def self.bot?(ua_string)
    normalized = ua_string.to_s.downcase
    return false if normalized.blank?

    bot_substrings.any? { |substring| normalized.include?(substring.downcase) }
  end

  # First-sight upsert: record a distinct UA once with its derived verdict.
  # A no-op once the UA is known (the verdict is refreshed in bulk by the
  # Phase 2 reclassify job, not on every sighting).
  def self.record(ua_string)
    return if ua_string.blank?

    find_or_create_by(ua_string:) do |row|
      row.is_bot = bot?(ua_string)
      row.classified_at = Time.current
    end
  end
end
