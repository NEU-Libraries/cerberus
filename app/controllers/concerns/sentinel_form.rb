# frozen_string_literal: true

# The parse of a Sentinel form's work access section, shared by the Collection
# and Set tabs. See docs/narrowing.md.
module SentinelForm
  extend ActiveSupport::Concern

  private

    # A blank visibility leaves each Work's own; "keep" leaves its groups. The
    # grant rows submit whatever the mode, so a list hidden by "keep" survives a
    # re-render, and are read only under "replace".
    def sentinel_work_access_from_params
      entry = params.fetch(:work_access, {})
      access = {}
      visibility = entry[:visibility].to_s
      access['visibility'] = visibility if Sentinel::VISIBILITIES.include?(visibility)
      access['grants'] = sentinel_grants_from(entry[:permissions]) if entry[:grants_mode] == 'replace'
      access.presence
    end

    # The entry row submits too, so a blank row is skipped, and `uniq` keeps a
    # group named twice from reaching Atlas twice.
    def sentinel_grants_from(rows)
      grants = Sentinel::GRANT_ABILITIES.index_with { [] }
      Array(rows&.values).each do |row|
        group = row[:group_id].presence
        ability = row[:ability].to_s
        next if group.nil? || grants.exclude?(ability)

        grants[ability] |= [group]
      end
      grants
    end
end
