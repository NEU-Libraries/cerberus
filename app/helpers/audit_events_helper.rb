# frozen_string_literal: true

# Shared formatting for audit-event rows. Each per-action partial
# (`_event_create.html.haml`, etc.) renders one row of three cells —
# when / action / who — via these helpers, and varies only the row's
# audit-event--<tone> class. The action cell carries both the tone chip
# and (inline, right of it) the quiet change_type + payload summary.
# Adding a new action type is still a new file, not a case-statement
# edit — these helpers are the scaffolding around that variation, not
# the variation itself.
# rubocop:disable Metrics/ModuleLength
# (Cohesive view-formatting for one component; length is mostly the rationale
# comments that make the chip / pill / summary choices legible.)
module AuditEventsHelper
  # Action descriptor — colour token + Font Awesome icon + display label.
  # Used by the action cell on every event row. Unknown actions fall
  # through to a neutral "generic" descriptor so a piece-5 action type
  # the helper hasn't been taught about still renders sensibly.
  ACTION_DESCRIPTORS = {
    'create'        => { tone: 'create',    icon: 'fa-circle-plus',  label: 'Created' },
    'update'        => { tone: 'update',    icon: 'fa-pen',          label: 'Updated' },
    'tombstone'     => { tone: 'tombstone', icon: 'fa-trash-can',    label: 'Tombstoned' },
    'restore'       => { tone: 'restore',   icon: 'fa-rotate-left',  label: 'Restored' },
    'reparent'      => { tone: 'reparent',  icon: 'fa-folder-tree',  label: 'Reparented' },
    'link_member'   => { tone: 'link',      icon: 'fa-link',         label: 'Linked' },
    'unlink_member' => { tone: 'unlink',    icon: 'fa-link-slash',   label: 'Unlinked' }
  }.freeze

  GENERIC_ACTION = { tone: 'generic', icon: 'fa-circle-info', label: nil }.freeze

  # change_type display labels. Surfaced as a quiet secondary qualifier on
  # rows whose action verb is ambiguous on its own — chiefly `update`, where
  # the same verb covers both a metadata edit and a permissions change. The
  # action chip stays the primary signal; this rides alongside it, muted.
  CHANGE_TYPE_LABELS = {
    'metadata'    => 'Metadata',
    'permissions' => 'Permissions',
    'structural'  => 'Structural',
    'lifecycle'   => 'Lifecycle',
    'session'     => 'Session'
  }.freeze

  # ACL grant slots diffed for a permissions-change summary; mirrors Atlas's
  # AUDITED_ACL_KEYS so the before/after snapshots line up key-for-key.
  ACL_DIFF_KEYS = %w[read edit edit_users].freeze

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

  # change_type category — a quiet uppercase micro-label (NOT a chip; a second
  # box would compete with the action chip). Returns nil when change_type is
  # blank so callers can render it unconditionally. The `--<change_type>`
  # modifier stays as a semantic/styling hook — notably permissions, the
  # eventual Permission-History link target (see _event_update.html.haml).
  def audit_event_change_type_badge(change_type)
    change_type = change_type.to_s
    return if change_type.blank?

    label = CHANGE_TYPE_LABELS.fetch(change_type) { change_type.humanize }
    content_tag(:span, label,
                class: "audit-event__change-type audit-event__change-type--#{change_type}")
  end

  # The DETAIL column cell: the change_type category label + payload summary,
  # in their own column so they left-align consistently across rows (trailing
  # a variable-width action chip, they wouldn't). A muted em-dash holds the
  # column for the rare event that carries no change_type or payload.
  def audit_event_detail_cell(event)
    audit_event_detail_line(event) ||
      content_tag(:span, '—', class: 'audit-event__detail-empty', 'aria-hidden': 'true')
  end

  # The change_type category label + a human summary of the event's payload
  # (changed fields, an ACL diff, a move target). Returns nil when there's
  # nothing to add.
  def audit_event_detail_line(event)
    badge   = audit_event_change_type_badge(event['change_type'])
    summary = audit_event_payload_summary(event)
    return if badge.nil? && summary.nil?

    safe_join([badge, summary].compact, ' ')
  end

  # The WHO cell — actor NUID pill, and (only in the rare proxy / acting-as
  # case) a muted "for <target>" beneath it. Merges what were two columns:
  # on-behalf-of is null on the overwhelming majority of rows, so a dedicated
  # column was pure horizontal tax. Actor + target are the same kind of fact.
  def audit_event_who(event)
    actor = audit_event_nuid(event['actor_nuid'])
    return actor if event['on_behalf_of_nuid'].blank?

    on_behalf = content_tag(:span, class: 'audit-event__on-behalf') do
      safe_join(['for ', audit_event_nuid(event['on_behalf_of_nuid'])])
    end
    content_tag(:div, safe_join([actor, on_behalf]), class: 'audit-event__who')
  end

  # Human one-liner derived from the event payload, by action. Returns a muted
  # span or nil. Shapes mirror what Atlas emits: update → { fields: [...] } |
  # { source: 'mods' } | { before:, after: } (ACL); reparent → { to: noid };
  # link/unlink → { collection: noid }. Create / tombstone / restore carry no
  # payload, so they render the category pill alone.
  def audit_event_payload_summary(event)
    text = payload_summary_text(event['action'].to_s, event['payload'] || {})
    return if text.blank?

    content_tag(:span, text, class: 'audit-event__detail-summary')
  end

  private

    def payload_summary_text(action, payload)
      case action
      when 'update'        then update_payload_summary(payload)
      when 'reparent'      then targeted_summary('moved to', payload['to'])
      when 'link_member'   then targeted_summary('to', payload['collection'])
      when 'unlink_member' then targeted_summary('from', payload['collection'])
      end
    end

    def targeted_summary(prefix, target)
      "#{prefix} #{target}" if target.present?
    end

    def update_payload_summary(payload)
      if payload['fields'].present? then payload['fields'].join(', ')
      elsif payload['source'].present? then 'MODS document'
      elsif payload['before'] || payload['after']
        acl_diff_summary(payload['before'] || {}, payload['after'] || {})
      end
    end

    # Per-grant +added / −removed summary across the audited ACL keys, e.g.
    # "read +public · edit −staff +editors". Empty when nothing actually moved.
    def acl_diff_summary(before, after)
      ACL_DIFF_KEYS.filter_map do |key|
        added   = Array(after[key]) - Array(before[key])
        removed = Array(before[key]) - Array(after[key])
        next if added.empty? && removed.empty?

        changes = removed.map { |g| "−#{g}" } + added.map { |g| "+#{g}" }
        "#{key.tr('_', ' ')} #{changes.join(' ')}"
      end.join(' · ').presence
    end
end
# rubocop:enable Metrics/ModuleLength
