# frozen_string_literal: true

# A write-once record that something happened, and the whole of the admin
# ledger: there is no lifecycle on these rows and no update path. See
# docs/admin.md.
class AdminNotice < ApplicationRecord
  REQUEST_KINDS = %w[request_withdraw request_move request_restrict].freeze

  ACTIVITY_KINDS = %w[load_report work_completion_mismatch visibility_cascade
                      set_reindex showcase_promotion set_privatize
                      set_sentinel_apply].freeze

  DIGEST = 'daily_digest'

  KINDS = (REQUEST_KINDS + ACTIVITY_KINDS + [DIGEST]).freeze

  validates :kind, inclusion: { in: KINDS }
  validates :subject, presence: true
  validates :occurred_on, presence: true
  # Enforced per kind because one shared table means these cannot be NOT NULL
  # columns: an activity row has no requester and often no subject.
  validates :actor_nuid, :subject_noid, presence: true, if: :request?

  before_validation :default_occurred_on

  scope :newest_first, -> { order(created_at: :desc) }
  # Order digests by the day they are about, not the moment they were written:
  # a re-run, or a backfill of several days at once, must not shuffle them out
  # of calendar order.
  scope :by_day,       -> { order(occurred_on: :desc, created_at: :desc) }
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :on_day,       ->(day) { where(occurred_on: day) }
  scope :requests,     -> { where(kind: REQUEST_KINDS) }
  scope :activity,     -> { where(kind: ACTIVITY_KINDS) }
  scope :digests,      -> { where(kind: DIGEST) }
  # An unknown filter value falls through to everything rather than to nothing,
  # so a hand-typed query string cannot render an empty page with no explanation.
  scope :of_kind,      ->(kind) { KINDS.include?(kind.to_s) ? where(kind: kind) : all }

  def request? = REQUEST_KINDS.include?(kind)
  def digest?  = kind == DIGEST

  def request_action = kind.to_s.delete_prefix('request_')

  # jsonb round-trips to string keys, so a caller that wrote `payload: { genre: }`
  # reads it back as `"genre"`. Read every payload field through here.
  def detail(key) = payload[key.to_s]

  private

    # Bucketing by a date column rather than a created_at range keeps a job that
    # runs late — or a re-run — attributed to the day it is about.
    def default_occurred_on
      self.occurred_on ||= Time.zone.today
    end
end
