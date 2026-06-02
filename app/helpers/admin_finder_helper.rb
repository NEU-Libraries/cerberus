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
  def finder_doc_title(doc)
    Array(doc['title_tsim']).first.presence || '(untitled)'
  end
end
