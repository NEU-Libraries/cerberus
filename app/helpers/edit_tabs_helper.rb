# frozen_string_literal: true

# The single, authoritative declaration of the resource-edit tab set. Never
# hand-mirror this list in a view — `shared/_edit_tabs` renders it for the
# edit pages and for the standalone XML editor. See docs/edit-surfaces.md.
module EditTabsHelper
  # A key doubles as the pane's DOM id (`#<key>`) and its tab button's id
  # (`<key>-tab`), so it must match the `.tab-pane` id in the edit view.
  TABS = {
    'Work'       => %w[metadata advanced permissions move delete xml history],
    'Collection' => %w[metadata permissions xml derivative-access export history analytics],
    'Community'  => %w[metadata permissions xml history analytics]
  }.freeze

  # Only where the label isn't the key humanized (see #edit_tab_label).
  LABELS = {
    'xml' => 'XML'
  }.freeze

  # Tabs that navigate to their own page instead of switching an in-page pane.
  STANDALONE = %w[xml].freeze

  def edit_tab_keys(klass)
    TABS.fetch(klass.to_s, []).select { |key| edit_tab_visible?(key) }
  end

  # The tab row and the panes both ask here, so they cannot disagree. `open`
  # names a pane explicitly because a re-render cannot use the URL fragment:
  # Turbo follows the redirect with fetch, and the Fetch spec drops it.
  def edit_tab_open_key(klass, open: nil)
    keys = edit_tab_keys(klass)
    return open if keys.include?(open) && !open.in?(STANDALONE)

    keys.find { |key| !key.in?(STANDALONE) }
  end

  # User-dependent gates only; class-dependent membership is TABS. The pane
  # in the edit view must share this predicate rather than re-test the ability.
  def edit_tab_visible?(key)
    case key
    when 'history' then can?(:read, :audit_event)
    when 'export'  then current_user&.loader_tier?.present?
    else true
    end
  end

  # Hyphens are swapped first: String#humanize only turns *underscores* into
  # spaces, so 'derivative-access' would label itself "Derivative-access".
  def edit_tab_label(key)
    LABELS.fetch(key) { key.tr('-', ' ').humanize }
  end

  def edit_tab_standalone_path(key, id)
    raise ArgumentError, "#{key} is not a standalone tab" unless key.in?(STANDALONE)

    xml_editor_path(id)
  end
end
