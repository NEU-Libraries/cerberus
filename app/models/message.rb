# frozen_string_literal: true

# An inbox message. Cerberus has no users table (User is session-only state
# hydrated from Atlas), so NUID strings are the key throughout: a nil
# sender_nuid marks a system-sent message, and the recipient is exactly one
# of a NUID or a Grouper group name (enforced here and by a DB check
# constraint).
class Message < ApplicationRecord
  has_many :receipts, class_name: 'MessageReceipt', dependent: :destroy

  normalizes :sender_nuid, :recipient_nuid, :recipient_group, with: ->(value) { value.presence }

  validates :subject, presence: true
  validate :exactly_one_recipient
  validate :recipient_is_not_guest

  scope :newest_first, -> { order(created_at: :desc) }

  # Read-time delivery: a message is in your inbox if it is addressed to your
  # NUID or to any group on your session. Group membership is never fanned out
  # to rows, so someone who joins a group later sees its past messages.
  def self.inbox_for(user)
    where(recipient_nuid: user.nuid)
      .or(where(recipient_group: user.groups.presence || []))
      .where.not(id: MessageReceipt.dismissed.where(nuid: user.nuid).select(:message_id))
      .newest_first
  end

  def self.unread_count_for(user)
    inbox_for(user)
      .where.not(id: MessageReceipt.read.where(nuid: user.nuid).select(:message_id))
      .count
  end

  def system?
    sender_nuid.blank?
  end

  def group_addressed?
    recipient_group.present?
  end

  private

    def exactly_one_recipient
      return if recipient_nuid.present? ^ recipient_group.present?

      errors.add(:base, 'Message must be addressed to exactly one recipient — a person or a group')
    end

    # Guests are excluded from the inbox entirely; the guest NUID is a shared
    # fallback identity for logged-out traffic, so a message to it would be a
    # dead letter nobody could ever read.
    def recipient_is_not_guest
      return if recipient_nuid.blank?
      return unless recipient_nuid == Rails.application.config.x.cerberus.guest_nuid

      errors.add(:recipient_nuid, 'cannot be the guest identity')
    end
end
