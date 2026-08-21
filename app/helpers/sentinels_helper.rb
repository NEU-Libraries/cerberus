# frozen_string_literal: true

# View helpers for the Collection edit page's Derivative access tab, which
# authors a Sentinel — the per-tier read-group default applied to new Works.
module SentinelsHelper
  # Display metadata per tier. The image rungs run widest audience (small) to
  # narrowest (master, the full-res source), with qualitative resolution notes —
  # the actual pixel sizes are per-Work, so a collection-level default names the
  # rung, not a number. The independent media (audio/video/pdf) name the file.
  DERIVATIVE_TIER_META = {
    'small'   => { label: 'Small',            note: 'Lowest-resolution download' },
    'medium'  => { label: 'Medium',           note: 'Mid-resolution download' },
    'large'   => { label: 'Large',            note: 'Highest-resolution download' },
    'service' => { label: 'Service',          note: 'Full-resolution deep-zoom' },
    'master'  => { label: 'Master / original', note: 'Full-resolution source file' },
    'audio'   => { label: 'Audio',            note: 'Downloadable audio rendition' },
    'video'   => { label: 'Video',            note: 'Downloadable video rendition' },
    'pdf'     => { label: 'PDF',              note: 'Downloadable PDF rendition' }
  }.freeze

  def derivative_tier_meta(tier)
    DERIVATIVE_TIER_META.fetch(tier)
  end

  # The tier's current form state from a (possibly nil) Sentinel: a public or
  # absent tier shows as Public; an explicit group list (including the empty
  # "restricted to nobody" list) shows as Restricted with those groups checked.
  def derivative_tier_form_state(sentinel, tier)
    groups = sentinel&.policy&.dig(tier)
    return { mode: 'public', groups: [] } if groups.nil? || groups == ['public']

    { mode: 'restrict', groups: Array(groups) }
  end

  # The group registry the tab's typeahead filters over, as JSON for the
  # Stimulus value. Rendered once for the whole ladder rather than once per
  # tier: every tier offers the same groups, and the list runs to dozens of
  # entries, so repeating it eight times is the markup the typeahead exists to
  # get rid of.
  def derivative_group_registry(groups)
    groups.map { |raw, cosmetic| { value: raw, label: cosmetic } }.to_json
  end
end
