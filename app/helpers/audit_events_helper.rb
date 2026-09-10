# frozen_string_literal: true

# Shared formatting for audit-event rows. Each per-action partial
# (`_event_create.html.haml`, etc.) renders one row through these helpers and
# varies only the row's audit-event--<tone> class. See docs/edit-surfaces.md.
module AuditEventsHelper
  # Action descriptor — colour token + icon + label. An action this helper
  # hasn't been taught about MUST still render: unknown verbs fall through
  # to GENERIC_ACTION rather than raising or rendering an empty chip.
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

  CHANGE_TYPE_LABELS = {
    'metadata'    => 'Metadata',
    'permissions' => 'Permissions',
    'structural'  => 'Structural',
    'lifecycle'   => 'Lifecycle',
    'session'     => 'Session'
  }.freeze

  # The ACL *grant* slots diffed for a permissions summary — a subset of
  # Atlas's AUDITED_ACL_KEYS. Do not add `embargo`: every renderer here treats
  # a key's value as a set of group tokens, and an embargo is a scalar date.
  ACL_DIFF_KEYS = %w[read edit edit_users].freeze

  EMBARGO_KEY = 'embargo'

  # Shared with HistoriesController#permission_events: both the initial grant
  # and every later ACL change carry a before/after snapshot worth a diff page.
  PERMISSION_VIEW_ACTIONS = %w[create update].freeze

  ACL_LEVEL_LABELS = {
    'read'       => 'Read',
    'edit'       => 'Edit',
    'edit_users' => 'Edit users',
    'embargo'    => 'Embargo'
  }.freeze

  # Atlas's tag for a per-rendition gate change. It rides the same
  # `permissions` change_type and action as an ACL edit, so `source` is the
  # only thing telling the two payload shapes apart — check it before reading.
  DERIVATIVE_PERMISSIONS_SOURCE = 'derivative_permissions'

  # Prose for the download tiers. The vocabulary and its narrowing order come
  # from Sentinel::TIERS; naming the ladder twice would let the two drift.
  TIER_LABELS = {
    'small'   => 'Small image',
    'medium'  => 'Medium image',
    'large'   => 'Large image',
    'service' => 'Service (deep zoom)',
    'master'  => 'Master (original)',
    'audio'   => 'Audio',
    'video'   => 'Video',
    'pdf'     => 'PDF'
  }.freeze

  def audit_event_action(event_action)
    ACTION_DESCRIPTORS.fetch(event_action.to_s) do
      GENERIC_ACTION.merge(label: event_action.to_s.humanize)
    end
  end

  def audit_event_timestamp(event)
    parsed = Time.iso8601(event['occurred_at'])
    content_tag(:div, class: 'audit-event__when', title: parsed.iso8601) do
      safe_join([
                  content_tag(:div, parsed.strftime('%Y-%m-%d'), class: 'audit-event__when-date'),
                  content_tag(:div, parsed.strftime('%H:%M UTC'), class: 'audit-event__when-time')
                ])
    end
  end

  def audit_event_nuid(nuid)
    if nuid.present?
      content_tag(:span, nuid, class: 'audit-event__nuid')
    else
      content_tag(:span, '—', class: 'audit-event__nuid audit-event__nuid--empty', 'aria-hidden': 'true')
    end
  end

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

  # Returns nil when change_type is blank, so callers can render it
  # unconditionally.
  def audit_event_change_type_badge(change_type)
    change_type = change_type.to_s
    return if change_type.blank?

    label = CHANGE_TYPE_LABELS.fetch(change_type) { change_type.humanize }
    content_tag(:span, label,
                class: "audit-event__change-type audit-event__change-type--#{change_type}")
  end

  def audit_event_detail_cell(event)
    audit_event_detail_line(event) ||
      content_tag(:span, '—', class: 'audit-event__detail-empty', 'aria-hidden': 'true')
  end

  def audit_event_detail_line(event)
    badge   = audit_event_change_type_badge(event['change_type'])
    summary = audit_event_payload_summary(event)
    return if badge.nil? && summary.nil?

    safe_join([badge, summary].compact, ' ')
  end

  def audit_event_who(event)
    actor = audit_event_actor(event['actor_nuid'])
    return actor if event['on_behalf_of_nuid'].blank?

    on_behalf = content_tag(:span, class: 'audit-event__on-behalf') do
      safe_join(['for ', audit_event_actor(event['on_behalf_of_nuid'])])
    end
    content_tag(:div, safe_join([actor, on_behalf]), class: 'audit-event__who')
  end

  def audit_event_actor(nuid)
    chip = audit_event_nuid(nuid)
    return chip if nuid.blank?

    name = NuidResolver.name_for(nuid)
    # The resolver echoes the NUID back when the directory has no entry — the
    # anonymous and system principals, and departed users. Rendering that as a
    # name would print the same digits twice, once bare and once chipped.
    return chip if name.blank? || name == nuid

    safe_join([content_tag(:span, name, class: 'audit-event__actor'), chip])
  end

  def audit_event_view_cell(event, resource_id)
    path = audit_event_view_path(event, resource_id)
    return if path.nil?

    link_to(path, class: 'btn btn-sm btn-outline-secondary audit-event__view-btn') do
      safe_join([
                  content_tag(:i, '', class: 'fa-solid fa-magnifying-glass', 'aria-hidden': 'true'),
                  'View'
                ], ' ')
    end
  end

  # Where a row's "View" button points, or nil if the row has no deep view.
  # A nil renders an empty cell, which is what keeps the column aligned.
  def audit_event_view_path(event, resource_id)
    case event['change_type']
    when 'permissions'
      return unless PERMISSION_VIEW_ACTIONS.include?(event['action'])

      rights_history_path(resource_id, at: event['occurred_at'], anchor: audit_event_dom_id(event))
    when 'metadata'
      return unless event['action'] == 'update'

      mods_history_path(resource_id, at: event['occurred_at'])
    end
  end

  def mods_version_options(versions)
    Array(versions).map do |version|
      label = [
        version['version_id'],
        mods_version_timestamp(version['created']),
        version['actor_nuid'].presence
      ].compact.join(' · ')
      [label, version['version_id']]
    end
  end

  def audit_event_dom_id(event)
    "evt-#{event['occurred_at'].to_s.gsub(/[^0-9]/, '')}"
  end

  def acl_level_label(key)
    ACL_LEVEL_LABELS.fetch(key.to_s) { key.to_s.humanize }
  end

  def acl_grant_pills(grants, marked: [], state: nil)
    grants = Array(grants)
    return content_tag(:span, '—', class: 'rights-diff__empty', 'aria-hidden': 'true') if grants.empty?

    marked = Array(marked)
    safe_join(grants.map do |grant|
      classes = ['rights-diff__pill']
      classes << "rights-diff__pill--#{state}" if state.present? && marked.include?(grant)
      content_tag(:span, grant, class: classes.join(' '))
    end, ' ')
  end

  # Whether a snapshot pair says anything at all about an embargo. Both no
  # cases must keep the row off the page: "None → None" reads as a change.
  def embargo_recorded?(before, after)
    before[EMBARGO_KEY].present? || after[EMBARGO_KEY].present?
  end

  # Compared through `presence` because "no embargo" reaches us as nil, '', or
  # an absent key depending on how the resource was created — all one fact.
  def embargo_changed?(before, after)
    before[EMBARGO_KEY].presence != after[EMBARGO_KEY].presence
  end

  def embargo_diff_cell(value, state: nil)
    date = embargo_date(value)
    return content_tag(:span, 'None', class: 'rights-diff__empty') if date.nil?

    classes = ['rights-diff__date']
    classes << "rights-diff__date--#{state}" if state.present?
    content_tag(:span, date.strftime('%B %-d, %Y'), class: classes.join(' '))
  end

  def derivative_permissions_payload?(payload)
    payload['source'] == DERIVATIVE_PERMISSIONS_SOURCE
  end

  # Only the tiers either side mentions, in Sentinel's narrowing order. An
  # unknown tier sorts last rather than vanishing, so a vocabulary Atlas grows
  # before Cerberus does still shows up.
  def derivative_tier_rows(before, after)
    (before.keys | after.keys).sort_by { |tier| Sentinel::TIERS.index(tier) || Sentinel::TIERS.length }
  end

  def tier_label(tier)
    TIER_LABELS.fetch(tier.to_s) { tier.to_s.humanize }
  end

  def audit_event_payload_summary(event)
    text = payload_summary_text(event['action'].to_s, event['payload'] || {})
    return if text.blank?

    content_tag(:span, text, class: 'audit-event__detail-summary')
  end

  private

    def mods_version_timestamp(created)
      return if created.blank?

      Time.iso8601(created).strftime('%Y-%m-%d %H:%M')
    rescue ArgumentError
      nil
    end

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

    # `source` is matched exactly, not merely for presence: Atlas uses the slot
    # for several unrelated things on an `update` row, and treating any of them
    # as the MODS marker labelled a rendition-gate change "MODS document".
    def update_payload_summary(payload)
      return payload['fields'].join(', ') if payload['fields'].present?
      return 'MODS document'              if payload['source'] == 'mods'
      return if payload['before'].nil? && payload['after'].nil?

      permissions_diff_summary(payload)
    end

    def permissions_diff_summary(payload)
      before = payload['before'] || {}
      after  = payload['after']  || {}
      return tier_diff_summary(before, after) if derivative_permissions_payload?(payload)

      acl_diff_summary(before, after)
    end

    def tier_diff_summary(before, after)
      derivative_tier_rows(before, after).filter_map do |tier|
        added   = Array(after[tier]) - Array(before[tier])
        removed = Array(before[tier]) - Array(after[tier])
        next if added.empty? && removed.empty?

        changes = removed.map { |g| "−#{g}" } + added.map { |g| "+#{g}" }
        "#{tier} #{changes.join(' ')}"
      end.join(' · ').presence
    end

    def acl_diff_summary(before, after)
      clauses = grant_diff_clauses(before, after)
      clauses << embargo_summary_clause(before, after) if embargo_changed?(before, after)
      clauses.join(' · ').presence
    end

    def grant_diff_clauses(before, after)
      ACL_DIFF_KEYS.filter_map do |key|
        added   = Array(after[key]) - Array(before[key])
        removed = Array(before[key]) - Array(after[key])
        next if added.empty? && removed.empty?

        changes = removed.map { |g| "−#{g}" } + added.map { |g| "+#{g}" }
        "#{key.tr('_', ' ')} #{changes.join(' ')}"
      end
    end

    def embargo_summary_clause(before, after)
      "embargo #{embargo_summary_value(before[EMBARGO_KEY])} → #{embargo_summary_value(after[EMBARGO_KEY])}"
    end

    def embargo_summary_value(value)
      embargo_date(value)&.iso8601 || 'none'
    end

    def embargo_date(value)
      return if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end
end
