# frozen_string_literal: true

# Shared formatting for audit-event rows. Each per-action partial
# (`_event_create.html.haml`, etc.) renders the same supporting cells
# (timestamp / actor / on-behalf-of) via these helpers and varies only
# the central "action" chip via the row's audit-event--<tone> class.
# Adding a new action type is still a new file, not a case-statement
# edit — these helpers are the scaffolding around that variation, not
# the variation itself.
module AuditEventsHelper
  # Action descriptor — colour token + Font Awesome icon + display label.
  # Used by the action cell on every event row. Unknown actions fall
  # through to a neutral "generic" descriptor so a piece-5 action type
  # the helper hasn't been taught about still renders sensibly.
  ACTION_DESCRIPTORS = {
    'create'    => { tone: 'create',    icon: 'fa-circle-plus',   label: 'Created' },
    'update'    => { tone: 'update',    icon: 'fa-pen',           label: 'Updated' },
    'tombstone' => { tone: 'tombstone', icon: 'fa-trash-can',     label: 'Tombstoned' },
    'restore'   => { tone: 'restore',   icon: 'fa-rotate-left',   label: 'Restored' }
  }.freeze

  GENERIC_ACTION = { tone: 'generic', icon: 'fa-circle-info', label: nil }.freeze

  def audit_event_action(event_action)
    ACTION_DESCRIPTORS.fetch(event_action.to_s) do
      GENERIC_ACTION.merge(label: event_action.to_s.humanize)
    end
  end

  # Date stacked above time, full ISO in title attribute. tabular-nums
  # via CSS so digits align column-to-column even though Bootstrap's
  # body font isn't monospace.
  def audit_event_timestamp(event)
    parsed = Time.iso8601(event['occurred_at'])
    content_tag(:div, class: 'audit-event__when', title: parsed.iso8601) do
      safe_join([
                  content_tag(:div, parsed.strftime('%Y-%m-%d'), class: 'audit-event__when-date'),
                  content_tag(:div, parsed.strftime('%H:%M UTC'), class: 'audit-event__when-time')
                ])
    end
  end

  # NUID chip — monospace pill that reads as an identifier rather than
  # body copy. Nil / blank renders as a muted em-dash placeholder.
  def audit_event_nuid(nuid)
    if nuid.present?
      content_tag(:span, nuid, class: 'audit-event__nuid')
    else
      content_tag(:span, '—', class: 'audit-event__nuid audit-event__nuid--empty', 'aria-hidden': 'true')
    end
  end

  # The action chip — tinted soft-badge containing icon + label. The
  # chip's background/border/text colours are driven by
  # `--audit-action-color`, set on the row via the audit-event--<tone>
  # class, so per-action partials don't need to repeat the colour. The
  # chip is the row's primary chromatic signal; the left rail
  # reinforces it for at-a-glance column scanning.
  def audit_event_action_badge(event)
    descriptor = audit_event_action(event['action'])
    content_tag(:span, class: 'audit-event__action') do
      safe_join([
                  content_tag(:i, '', class:         "fa-solid #{descriptor[:icon]} audit-event__action-icon",
                                      'aria-hidden': 'true'),
                  content_tag(:span, descriptor[:label], class: 'audit-event__action-label')
                ])
    end
  end
end
