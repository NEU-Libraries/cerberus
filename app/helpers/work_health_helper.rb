# frozen_string_literal: true

# Renders Atlas's Work health report: the grade, the findings, and the surface
# that repairs each one. Shared by the edit page's Health tab and the admin
# lookup. See docs/work-health.md.
module WorkHealthHelper
  FRAME_ID = 'work-health'

  # The word carries the meaning, so the grade still reads without its colour.
  GRADE_LABELS = {
    'green'  => 'Green: viable',
    'yellow' => 'Yellow: repairable, nothing lost',
    'red'    => 'Red: content lost; restore or re-deposit'
  }.freeze

  # Display order. A severity Atlas adds later sorts after these, as a problem.
  SEVERITIES = %w[fatal repairable advisory].freeze

  # Atlas's codes are an open vocabulary: a code missing here renders its
  # message with no repair link, never an error.
  REPAIR_TABS = {
    'untitled'                     => 'metadata',
    'mods_access_copy_missing'     => 'xml',
    'descriptive_file_set_missing' => 'xml',
    'mods_xml_missing'             => 'xml',
    'orphaned'                     => 'move',
    'parent_missing'               => 'move',
    'wrong_parent_type'            => 'move',
    'staff_edit_missing'           => 'permissions',
    'no_depositor'                 => 'permissions',
    'live_under_withdrawn'         => 'delete'
  }.freeze

  REINDEX_CODES = %w[not_indexed].freeze

  def work_health_grade_label(grade)
    GRADE_LABELS.fetch(grade.to_s) { grade.to_s.humanize.presence || 'Ungraded' }
  end

  # Fatal first, then repairable. Advisory findings are states rather than
  # damage, so the view shows them apart.
  def work_health_problems(findings)
    Array(findings).reject { |f| f['severity'] == 'advisory' }
                   .sort_by { |f| SEVERITIES.index(f['severity']) || SEVERITIES.size }
  end

  def work_health_advisories(findings)
    Array(findings).select { |f| f['severity'] == 'advisory' }
  end

  def work_health_severity_label(severity)
    severity.to_s.humanize.presence || 'Unknown'
  end

  # The tone class names only the severities with a colour of their own.
  def work_health_tone(value)
    known = SEVERITIES + GRADE_LABELS.keys
    "work-health--#{known.include?(value.to_s) ? value : 'unknown'}"
  end

  def work_health_subject(subject, work_id)
    return tag.span('—', class: 'audit-event__detail-empty') if subject.blank?
    return 'this Work' if subject == work_id

    tag.span(subject, class: 'audit-event__nuid')
  end

  # `standalone` is the admin lookup, which has no tabs beside it, so a repair
  # opens the edit page there rather than switching the pane in place.
  def work_health_repair(finding, work_id, standalone: false)
    code = finding['code'].to_s
    return work_health_reindex_button(work_id, standalone:) if code.in?(REINDEX_CODES)

    key = REPAIR_TABS[code]
    return tag.span('—', class: 'audit-event__detail-empty') if key.nil?

    work_health_tab_link(key, work_id, standalone:)
  end

  def work_health_reload_path(work_id, standalone: false)
    standalone ? admin_work_health_path(noid: work_id) : health_work_path(work_id)
  end

  private

    # `_top`, because inside the tab's frame a link would otherwise load the
    # edit page into the frame. A bare fragment stays in the page: tab-hash
    # switches the pane on hashchange.
    def work_health_tab_link(key, work_id, standalone:)
      label = "Open #{key == 'xml' ? 'the XML editor' : "the #{edit_tab_label(key)} tab"}"
      if key == 'xml'
        link_to label, xml_editor_path(work_id), data: { turbo_frame: '_top' }
      elsif standalone
        link_to label, edit_work_path(work_id, tab: key)
      else
        link_to label, "##{key}", data: { turbo: false }
      end
    end

    # Comes back to the report it was pressed on, so the operator sees the new
    # grade rather than the show page.
    def work_health_reindex_button(work_id, standalone:)
      back = standalone ? admin_work_health_path(noid: work_id) : edit_work_path(work_id, tab: 'health')
      button_to 'Reindex', admin_reindex_work_path(work_id),
                params:     { return_to: back },
                class:      'btn btn-tonal-primary btn-sm',
                form:       { data: { turbo_frame: '_top' } },
                form_class: 'd-inline'
    end
end
