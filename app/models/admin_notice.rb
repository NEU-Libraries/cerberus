# frozen_string_literal: true

# A write-once record that something happened, for the admin dashboard's
# activity list. Nothing inside Cerberus works these rows — a librarian reads
# the list and acts elsewhere — so there is no read or dismiss state on them,
# and no update path at all.
#
# The payload holds structured detail rather than prose because two renderers
# read it: the ledger builds paths from the noids it carries, and a mailer
# would build absolute URLs from the same fields. A rendered link could serve
# neither, since it fixes the host — or omits it — at write time.
class AdminNotice < ApplicationRecord
  KINDS = %w[load_report work_completion_mismatch visibility_cascade
             set_reindex showcase_promotion daily_digest].freeze

  DIGEST = 'daily_digest'

  validates :kind, inclusion: { in: KINDS }
  validates :subject, presence: true
  validates :occurred_on, presence: true

  before_validation :default_occurred_on

  scope :newest_first, -> { order(created_at: :desc) }
  scope :on_day,       ->(day) { where(occurred_on: day) }
  # An unknown filter value falls through to everything rather than to nothing,
  # so a hand-typed query string cannot render an empty page with no explanation.
  scope :of_kind,      ->(kind) { KINDS.include?(kind.to_s) ? where(kind: kind) : all }

  def digest? = kind == DIGEST

  # jsonb round-trips to string keys, so a caller that wrote `payload: { genre: }`
  # reads it back as `"genre"`. Every reader goes through here rather than
  # guessing which side of the write it is on.
  def detail(key) = payload[key.to_s]

  private

    # The day the event belongs to, in the app's zone. Bucketing by a date
    # column rather than a created_at range keeps a job that runs late — or a
    # re-run — attributed to the day it is about.
    def default_occurred_on
      self.occurred_on ||= Time.zone.today
    end
end
