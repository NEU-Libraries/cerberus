# frozen_string_literal: true

# View helpers for the forms that author a Sentinel: the Collection edit page's
# Derivative access tab and the Set edit page's Work permissions tab.
module SentinelsHelper
  # Display metadata per tier. The image rungs run widest audience (small) to
  # narrowest (original, the full-res source), with qualitative resolution notes —
  # the actual pixel sizes are per-Work, so a collection-level default names the
  # rung, not a number. The independent media (audio/video/pdf) name the file.
  DERIVATIVE_TIER_META = {
    'small'    => { label: 'Small',    note: 'Lowest-resolution download' },
    'medium'   => { label: 'Medium',   note: 'Mid-resolution download' },
    'large'    => { label: 'Large',    note: 'Highest-resolution download' },
    'service'  => { label: 'Service',  note: 'Full-resolution deep-zoom' },
    'original' => { label: 'Original', note: 'Full-resolution source file' },
    'audio'    => { label: 'Audio',    note: 'Downloadable audio file' },
    'video'    => { label: 'Video',    note: 'Downloadable video file' },
    'pdf'      => { label: 'PDF',      note: 'Downloadable PDF file' }
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

  # The Sentinel's replacement grants as the shared grant editor's rows. Every
  # row is revocable: these are a policy being authored, not grants on a
  # resource, so Atlas's removal rule does not reach them.
  def sentinel_grant_rows(sentinel, groups)
    labels = groups.to_h
    Array(sentinel&.grants).flat_map do |ability, ids|
      Array(ids).map do |id|
        Permissions::GrantRow.new(group_id: id, label: labels.fetch(id, id), ability: ability, revocable: true)
      end
    end
  end

  # What applying this Sentinel to a Set will do, one sentence per part, for the
  # pane and the confirmation. Read from the saved record, because Apply sweeps
  # what was saved rather than what the form shows.
  def sentinel_apply_summary(sentinel)
    [visibility_summary(sentinel), grants_summary(sentinel), derivatives_summary(sentinel)].compact
  end

  # Only widening is called out: it is the one change that discloses material,
  # so it is the one the confirmation must name.
  def sentinel_widens?(sentinel)
    sentinel&.visibility == 'public'
  end

  private

    def visibility_summary(sentinel)
      case sentinel.visibility
      when 'public' then 'Every work is made public, where its collection allows it.'
      when 'private' then 'Every work is made private.'
      end
    end

    def grants_summary(sentinel)
      return if sentinel.grants.nil?

      count = sentinel.grants.values.sum(&:size)
      return 'Every group grant is removed from every work.' if count.zero?

      "Every work's group grants are replaced with the #{pluralize(count, 'grant')} saved here."
    end

    def derivatives_summary(sentinel)
      return unless sentinel.derivatives_enabled

      'Every work\'s derivative access is set to the policy saved here.'
    end
end
