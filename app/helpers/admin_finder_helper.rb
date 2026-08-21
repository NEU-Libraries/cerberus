# frozen_string_literal: true

# Shared view helpers for the admin finder surfaces (re-parent, linked members).
module AdminFinderHelper
  # DRS semantic iconography (matches CLAUDE.md's UI guidance + breadcrumb/show
  # usage): Collection = open folder, Community = users, Work = file.
  RESOURCE_ICONS = {
    'Collection' => 'fa-folder-open',
    'Community'  => 'fa-users',
    'Work'       => 'fa-file-lines'
  }.freeze

  # A small, restrained type chip (icon + label) for a resource row.
  def finder_type_chip(klass)
    icon = RESOURCE_ICONS.fetch(klass.to_s, 'fa-cube')
    content_tag(:span, class: 'reparent-type') do
      concat content_tag(:i, '', class: "fa-solid #{icon}", 'aria-hidden' => 'true')
      concat " #{klass}"
    end
  end

  # First title value off a resource Solr doc (title_tsim is multivalued), with a
  # clear fallback so an untitled resource is still selectable.
  #
  # Plain text, because most callers put the title somewhere markup cannot
  # render — a confirm dialog, a query string, a table cell built by
  # interpolation. Element content that can show a subscript asks for it
  # explicitly via finder_doc_heading.
  def finder_doc_title(doc)
    plain_text(Array(doc['title_tsim']).first.presence || '(untitled)')
  end

  # finder_doc_title for a place that renders markup: an admin table cell or a
  # link label, where a formula's subscript should read as one.
  def finder_doc_heading(doc)
    enhanced_text(Array(doc['title_tsim']).first.presence || '(untitled)')
  end

  # When a resource was last written, for the deposit-triage list.
  #
  # Called "last change" and not "waiting since", which is what a triage reader
  # actually wants to know but not what the field says: `updated_at_dtsi` is the
  # most recent write of any kind, so a derivative job touching an abandoned
  # deposit moves it. Naming it for the field keeps the column honest, and it still
  # sorts the list usefully — the deposit nothing has touched in a month sinks to
  # the top.
  def deposit_last_change(doc)
    stamp = doc['updated_at_dtsi']
    return content_tag(:span, '—') if stamp.blank?

    parsed = Time.iso8601(stamp)
    content_tag(:span, parsed.strftime('%Y-%m-%d'), class: 'admin-registry-table__when',
                                                    title: parsed.iso8601)
  end
end
