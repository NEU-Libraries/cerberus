# frozen_string_literal: true

module ReparentHelper
  # DRS semantic container iconography (matches CLAUDE.md's UI guidance and the
  # breadcrumb/show usage): Collection = open folder, Community = users.
  CONTAINER_ICONS = {
    'Collection' => 'fa-folder-open',
    'Community'  => 'fa-users'
  }.freeze

  # A small, restrained type chip (icon + label) for a container row.
  def reparent_type_chip(klass)
    icon = CONTAINER_ICONS.fetch(klass.to_s, 'fa-cube')
    content_tag(:span, class: 'reparent-type') do
      concat content_tag(:i, '', class: "fa-solid #{icon}", 'aria-hidden' => 'true')
      concat " #{klass}"
    end
  end

  # First title value off a container Solr doc (title_tsim is multivalued),
  # with a clear fallback so an untitled container is still selectable.
  def reparent_doc_title(doc)
    Array(doc['title_tsim']).first.presence || '(untitled)'
  end
end
