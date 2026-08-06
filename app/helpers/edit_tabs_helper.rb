# frozen_string_literal: true

# The single declaration of the resource-edit tab set — which tabs a
# Work/Collection/Community edit page offers, in what order, and who may see
# each one. Rendered by shared/_edit_tabs, which the edit pages themselves and
# the standalone XML editor both use.
#
# It lives in one place because it used to live in four (the three edit views
# plus the XML editor's hand-mirrored copy) with nothing coupling them, so the
# XML editor's row silently went stale every time a tab was added — it was
# missing Derivative access, Export and Analytics, and had XML in the wrong
# position for containers. Adding a tab now means one entry in TABS plus the
# pane itself in that class's edit view.
module EditTabsHelper
  # Per-class tab keys, in display order. Order and membership are data, so a
  # class-specific tab needs no conditional anywhere: Analytics is
  # container-only and Advanced/Move/Delete are Work-only purely by virtue of
  # which arrays list them.
  #
  # A key doubles as the pane's DOM id (`#<key>`) and its tab button's id
  # (`<key>-tab`), so it must match the `.tab-pane` id in the edit view.
  TABS = {
    'Work'       => %w[metadata advanced permissions move delete xml history],
    'Collection' => %w[metadata permissions xml derivative-access export history analytics],
    'Community'  => %w[metadata permissions xml history analytics]
  }.freeze

  # Only where the label isn't the key humanized — i.e. genuine exceptions like
  # an acronym, not merely hyphenated keys (see #edit_tab_label).
  LABELS = {
    'xml' => 'XML'
  }.freeze

  # Tabs that navigate to their own page instead of switching an in-page pane.
  STANDALONE = %w[xml].freeze

  # @param klass [String] 'Work' | 'Collection' | 'Community'.
  # @return [Array<String>] the keys this viewer may see, in display order.
  def edit_tab_keys(klass)
    TABS.fetch(klass.to_s, []).select { |key| edit_tab_visible?(key) }
  end

  # Which pane opens when the page loads. The tab row and the panes have to
  # agree on this, so both ask here rather than each deciding for itself.
  #
  # `open` names a pane explicitly, which a re-render needs: a rejected save
  # must come back on the tab the reader was working in. It cannot rely on the
  # URL fragment for that, because Turbo follows a redirect with fetch and the
  # Fetch spec drops the fragment from the resolved URL — the Location header
  # carries it and the browser never sees it. An unknown or hidden key falls
  # back to the default rather than opening nothing.
  #
  # @param klass [String] 'Work' | 'Collection' | 'Community'.
  # @param open [String, nil] key of the pane to open, if not the first.
  # @return [String, nil] the key of the pane that opens.
  def edit_tab_open_key(klass, open: nil)
    keys = edit_tab_keys(klass)
    return open if keys.include?(open) && !open.in?(STANDALONE)

    keys.find { |key| !key.in?(STANDALONE) }
  end

  # Whether this viewer may see a tab. Only *user*-dependent gates live here —
  # class-dependent membership is TABS above. The edit view's pane must share
  # this predicate rather than re-testing the underlying ability, so a gate is
  # declared exactly once and the tab and its pane can't disagree.
  def edit_tab_visible?(key)
    case key
    when 'history' then can?(:read, :audit_event)
    when 'export'  then current_user&.loader_tier?.present?
    else true
    end
  end

  # Keys are hyphenated to match their DOM ids, and String#humanize only turns
  # *underscores* into spaces — so hyphens are swapped first, or
  # 'derivative-access' would label itself "Derivative-access".
  def edit_tab_label(key)
    LABELS.fetch(key) { key.tr('-', ' ').humanize }
  end

  # Where a standalone tab points. Only XML today; a second one would join the
  # case rather than growing a path-guessing convention.
  def edit_tab_standalone_path(key, id)
    raise ArgumentError, "#{key} is not a standalone tab" unless key.in?(STANDALONE)

    xml_editor_path(id)
  end
end
