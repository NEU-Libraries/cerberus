# frozen_string_literal: true

# Per-recipient read/dismiss state, created lazily on first interaction so it
# works identically for direct and group-addressed messages (group delivery is
# evaluated at read time — there are no per-recipient rows until someone acts).
class MessageReceipt < ApplicationRecord
  belongs_to :message

  validates :nuid, presence: true, uniqueness: { scope: :message_id }

  scope :read,      -> { where.not(read_at: nil) }
  scope :dismissed, -> { where.not(deleted_at: nil) }

  def self.mark_read!(message, nuid)
    touch_state!(message, nuid, :read_at)
  end

  def self.dismiss!(message, nuid)
    touch_state!(message, nuid, :deleted_at)
  end

  # First touch wins: a timestamp is only ever set once, so re-opening a
  # message keeps the original read_at. Tolerates the concurrent
  # first-receipt race via the (message_id, nuid) unique index.
  def self.touch_state!(message, nuid, column)
    receipt = find_or_create_by!(message: message, nuid: nuid)
    receipt.update!(column => Time.current) if receipt[column].blank?
    receipt
  rescue ActiveRecord::RecordNotUnique
    retry
  end
  private_class_method :touch_state!
end
