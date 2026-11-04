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

  # Marks many messages read in one write, and returns how many were unread. A
  # group message has no receipt until someone acts on it, so this inserts the
  # missing rows. COALESCE keeps first-touch-wins for a receipt that gained a
  # read_at between the read and the write.
  def self.mark_many_read!(message_ids, nuid)
    unread = message_ids - read.where(nuid: nuid, message_id: message_ids).pluck(:message_id)
    return 0 if unread.empty?

    now = Time.current
    rows = unread.map { |id| { message_id: id, nuid: nuid, read_at: now } }
    # The only validations are a present nuid, which the caller always passes,
    # and the (message_id, nuid) uniqueness that the unique index enforces here.
    upsert_all(rows, # rubocop:disable Rails/SkipsModelValidations
               unique_by:    %i[message_id nuid],
               on_duplicate: Arel.sql('read_at = COALESCE(message_receipts.read_at, EXCLUDED.read_at)'))
    unread.size
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
