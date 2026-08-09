# frozen_string_literal: true

# A write-once record that something happened, and the whole of the admin
# ledger. Nothing here is worked inside Cerberus — staff read a list, act on
# the object's own surface, and coordinate with each other and with depositors
# off-site — so there is no lifecycle on these rows and no update path.
#
# Two families share the table because nothing structural separates them. A
# request ("somebody asked for this work to be withdrawn") and an event ("a
# cascade finished") are both an attributed fact with a subject and some
# detail. They differ only in which question a reader is asking, which is what
# the two ledger tabs are: a filter on kind.
#
# The payload holds kind-specific detail rather than prose because two
# renderers read it: the ledger builds paths from the noids it carries, and a
# mailer would build absolute URLs from the same fields. A rendered link could
# serve neither, since it fixes the host — or omits it — at write time.
class AdminNotice < ApplicationRecord
  # What a depositor may ask staff to do but cannot do themselves.
  REQUEST_KINDS = %w[request_withdraw request_move request_restrict].freeze

  # What the repository did on its own account.
  ACTIVITY_KINDS = %w[load_report work_completion_mismatch visibility_cascade
                      set_reindex showcase_promotion].freeze

  # A whole day, summed up. Its own family because it is a different size of
  # thing: every other row is one event, and a page-sized summary among them
  # buries them and reads badly itself.
  DIGEST = 'daily_digest'

  KINDS = (REQUEST_KINDS + ACTIVITY_KINDS + [DIGEST]).freeze

  validates :kind, inclusion: { in: KINDS }
  validates :subject, presence: true
  validates :occurred_on, presence: true
  # One table means these cannot be NOT NULL columns — an activity row has no
  # requester and often no subject. Enforced per kind instead: a request with
  # nobody asking, or nothing asked about, is a row nobody could act on.
  validates :actor_nuid, :subject_noid, presence: true, if: :request?

  before_validation :default_occurred_on

  scope :newest_first, -> { order(created_at: :desc) }
  # Digests are ordered by the day they are about, not the moment they were
  # written: a re-run, or a backfill of several days at once, must not shuffle
  # them out of calendar order.
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

  # 'withdraw' / 'move' / 'restrict' — the verb inside a request kind.
  def request_action = kind.to_s.delete_prefix('request_')

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
