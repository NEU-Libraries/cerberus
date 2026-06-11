# frozen_string_literal: true

# The system's voice in the User Inbox — the v1 "process finished" emails
# reborn in-app. A nil sender_nuid is what marks a Message as system-sent;
# this service is the one place that mints them.
class SystemMessage
  # @return [Message, nil] nil when the addressee is the guest identity
  #   (guests have no inbox; see Message#recipient_is_not_guest).
  def self.deliver(subject:, body: nil, to_nuid: nil, to_group: nil)
    return if to_nuid.present? && to_nuid == Rails.application.config.x.cerberus.guest_nuid

    Message.create!(
      sender_nuid:     nil,
      subject:         subject,
      body:            body,
      recipient_nuid:  to_nuid,
      recipient_group: to_group
    )
  end
end
