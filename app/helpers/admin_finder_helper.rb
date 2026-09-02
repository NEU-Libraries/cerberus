# frozen_string_literal: true

# Shared view helpers for the admin finder and registry surfaces (re-parent,
# linked members, deposit triage). See docs/admin.md.
module AdminFinderHelper
  RESOURCE_ICONS = {
    'Collection' => 'fa-folder-open',
    'Community'  => 'fa-users',
    'Work'       => 'fa-file-lines'
  }.freeze

  def finder_type_chip(klass)
    icon = RESOURCE_ICONS.fetch(klass.to_s, 'fa-cube')
    content_tag(:span, class: 'reparent-type') do
      concat content_tag(:i, '', class: "fa-solid #{icon}", 'aria-hidden' => 'true')
      concat " #{klass}"
    end
  end

  # Plain text, because most callers put the title where markup cannot render —
  # a confirm dialog, a query string, an interpolated cell. Use
  # finder_doc_heading where a subscript should render as one.
  def finder_doc_title(doc)
    plain_text(Array(doc['title_tsim']).first.presence || '(untitled)')
  end

  def finder_doc_heading(doc)
    enhanced_text(Array(doc['title_tsim']).first.presence || '(untitled)')
  end

  # `updated_at_dtsi` is the most recent write of any kind, not how long the
  # deposit has waited. Keep this column labelled "last change".
  def deposit_last_change(doc)
    stamp = doc['updated_at_dtsi']
    return content_tag(:span, '—') if stamp.blank?

    parsed = Time.iso8601(stamp)
    content_tag(:span, parsed.strftime('%Y-%m-%d'), class: 'admin-registry-table__when',
                                                    title: parsed.iso8601)
  end
end
