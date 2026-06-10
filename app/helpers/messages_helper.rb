# frozen_string_literal: true

# Formatting for the User Inbox. Sender identity reuses the audit-event NUID
# chip so identifiers read the same across surfaces.
module MessagesHelper
  def unread_messages_count
    @unread_messages_count ||= current_user&.messageable? ? Message.unread_count_for(current_user) : 0
  end

  def inbox_aria_label
    count = unread_messages_count
    count.positive? ? "Inbox, #{count} unread" : 'Inbox'
  end

  # Sender cell: a fixed "DRS" chip for system messages; resolved name plus
  # NUID chip for a human sender. `names` is a batch-resolved nuid => name
  # hash (NuidResolver.names_for) so index rows don't resolve one-by-one.
  def message_sender(message, names = {})
    return tag.span('DRS', class: 'inbox-sender inbox-sender--system') if message.system?

    name = names[message.sender_nuid] || message.sender_nuid
    safe_join([tag.span(name, class: 'inbox-sender'), audit_event_nuid(message.sender_nuid)], ' ')
  end

  def message_group_chip(message)
    tag.span(class: 'inbox-group-chip') do
      safe_join([tag.i(class: 'fa-solid fa-users me-1', 'aria-hidden': 'true'),
                 pretty_group_name(message.recipient_group)])
    end
  end

  # Mirrors ApplicationController#pretty_group, which isn't exposed to views.
  def pretty_group_name(raw_group)
    Group.find_by(raw: raw_group)&.cosmetic || raw_group
  end

  def message_timestamp(time)
    tag.time(time.strftime('%b %-d, %Y · %H:%M'), datetime: time.iso8601, class: 'inbox-timestamp')
  end

  # Bodies are plain text by design; the one affordance system messages need
  # is an in-app link ("View the report: /loaders/…"). Escape everything,
  # then turn root-relative paths into anchors.
  def message_body(body)
    escaped = CGI.escapeHTML(body.to_s)
    linked = escaped.gsub(%r{(^|[\s(])(/[\w\-/.?=&;%#]+)}) do
      "#{Regexp.last_match(1)}<a href=\"#{Regexp.last_match(2)}\">#{Regexp.last_match(2)}</a>"
    end
    simple_format(linked, {}, sanitize: false)
  end
end
