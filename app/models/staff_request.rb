# frozen_string_literal: true

# Something an editor may ask for but not perform: withdraw or move a Work,
# restrict a Collection or Community. Cerberus has no users table (User is
# session-only state hydrated from Atlas), so NUID strings are the key here as
# they are on Message.
#
# This is a table rather than a group-addressed Message because the state has
# to be shared. A message is dismissed per person, so one person fulfilling a
# request leaves it unread for everyone else and records nothing about who
# acted.
#
# Staff fulfil a request with the tools that already exist — the show-page
# tombstone, the admin re-parent finder, the Collection edit page's permissions
# cascade — and then resolve it here. The ledger deliberately carries no
# remedy of its own.
class StaffRequest < ApplicationRecord
  KINDS         = %w[withdraw move restrict].freeze
  SUBJECT_TYPES = %w[Work Collection Community].freeze
  STATUSES      = %w[open claimed resolved].freeze
  RESOLUTIONS   = %w[done declined].freeze

  # Only :admin may run a visibility cascade, so only :admin can fulfil a
  # restrict. The ledger is reachable by the devolved-admin tier as well, which
  # sees the row and is told an administrator has to act.
  ADMIN_ONLY_KINDS = %w[restrict].freeze

  # Narrowing a Community does not cascade, and no form offers it — so whoever
  # fulfils the request has to be told how, or the request is unanswerable.
  # Restricting each Collection inside cascades (and confirms) on its own, which
  # is why that is the route rather than a Community-wide sweep.
  COMMUNITY_REMEDY = 'Restricting a community does not reach what is inside it. Restrict each collection ' \
                     'within it first — each of those cascades to its own contents — then the community.'

  normalizes :subject_title, :note, :resolution_note, :resolution, with: ->(value) { value.presence }

  validates :kind, inclusion: { in: KINDS }
  validates :subject_type, inclusion: { in: SUBJECT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :resolution, inclusion: { in: RESOLUTIONS }, allow_nil: true
  validates :subject_noid, :requester_nuid, presence: true

  # A queue is worked from the back: the request that has waited longest is the
  # one somebody forgot. Same order as the deposit triage list.
  scope :oldest_first,  -> { order(created_at: :asc) }
  scope :unresolved,    -> { where.not(status: 'resolved') }
  scope :opened_on,     ->(day) { where(created_at: day.all_day) }
  scope :resolved_on,   ->(day) { where(resolved_at: day.all_day) }
  # An unknown filter value falls through to everything rather than to nothing,
  # so a hand-typed query string cannot render an empty page with no explanation.
  scope :with_status,   ->(status) { STATUSES.include?(status.to_s) ? where(status: status) : all }

  def open?     = status == 'open'
  def claimed?  = status == 'claimed'
  def resolved? = status == 'resolved'

  def admin_only? = ADMIN_ONLY_KINDS.include?(kind)

  # Guidance the fulfiller needs and cannot infer from the row, or nil.
  def remedy_note
    COMMUNITY_REMEDY if kind == 'restrict' && subject_type == 'Community'
  end

  # A claim is advisory, not a lock. It tells the rest of the team somebody has
  # picked this up; it does not stop anyone else resolving the request, because
  # the remedy lives on another surface where no claim could be enforced anyway.
  def claim!(nuid)
    return false if resolved?

    update!(status: 'claimed', claimed_by_nuid: nuid, claimed_at: Time.current)
  end

  def unclaim!
    return false if resolved?

    update!(status: 'open', claimed_by_nuid: nil, claimed_at: nil)
  end

  def resolve!(nuid:, resolution: 'done', note: nil)
    update!(status: 'resolved', resolution: resolution, resolution_note: note,
            resolved_by_nuid: nuid, resolved_at: Time.current)
  end
end
