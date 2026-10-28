# frozen_string_literal: true

# The Work-level half of a Sentinel: an optional change to the Work's own ACL,
# applied beside the derivative tiers. Absent means the Work's ACL is left
# alone. See docs/narrowing.md.
module SentinelWorkAccess
  extend ActiveSupport::Concern

  VISIBILITIES = %w[public private].freeze
  GRANT_ABILITIES = %w[read edit].freeze

  included do
    before_validation { self.work_access = nil if work_access.blank? }

    validate :work_access_well_formed
    validate :work_access_within_resource
  end

  # The ACL keys this Sentinel would send for a Work holding `current`, or nil
  # when it leaves the ACL alone. A visibility it does not name keeps the Work's
  # own; grants it names replace the Work's groups outright.
  def work_envelope(current)
    return if work_access.blank?

    read_now = Array(current&.read)
    groups = grants ? Array(grants['read']) : read_now - ['public']
    open = { 'public' => true, 'private' => false }.fetch(visibility, read_now.include?('public'))
    envelope = { 'read' => ((open ? ['public'] : []) + groups).uniq }
    envelope['edit'] = Array(grants['edit']).uniq if grants
    envelope
  end

  def visibility
    work_access&.dig('visibility')
  end

  def grants
    work_access&.dig('grants')
  end

  private

    # Atlas prepends the staff group to every edit it writes, so it is left out
    # of both sides of the comparison and of the ledger.
    def editable_groups(current)
      Array(current&.edit) - [Permissions::STAFF_EDIT_GROUP]
    end

    def acl_change?(envelope, current)
      now = { 'read' => Array(current.read), 'edit' => editable_groups(current) }
      envelope.any? { |key, groups| groups.sort != now[key].sort }
    end

    def clamped_work_access(read_groups)
      return work_access if work_access.blank?

      access = work_access.deep_dup
      access.delete('visibility') if visibility == 'public' && Array(read_groups).exclude?('public')
      if grants
        access['grants'] = grants.merge('read' => Permissions.audience_intersect(Array(grants['read']), read_groups))
      end
      access.presence
    end

    def work_access_well_formed
      return if work_access.nil?
      return errors.add(:work_access, 'must be a hash') unless work_access.is_a?(Hash)

      stray = work_access.keys - %w[visibility grants]
      errors.add(:work_access, "unknown key '#{stray.first}'") if stray.any?
      if visibility && VISIBILITIES.exclude?(visibility)
        errors.add(:work_access, "visibility must be one of #{VISIBILITIES.join(', ')}")
      end
      grants_well_formed
    end

    # `public` is a visibility, not a group, so it is refused as a grant: a
    # grant list is a replacement, and carrying it there would undo the
    # visibility choice beside it.
    def grants_well_formed
      return if grants.nil?
      return errors.add(:work_access, 'grants must be a hash') unless grants.is_a?(Hash)

      grants.each do |ability, groups|
        errors.add(:work_access, "unknown ability '#{ability}'") unless GRANT_ABILITIES.include?(ability.to_s)
        next errors.add(:work_access, "'#{ability}' must be a list of groups") unless groups.is_a?(Array)

        errors.add(:work_access, "'public' is a visibility, not a group") if groups.include?('public')
      end
    end

    # Atlas refuses a Work more visible than its Collection, so a default that
    # breaks this would fail every ingest. Skipped when the container's groups
    # weren't supplied, as for a Set.
    def work_access_within_resource
      return if resource_read_groups.nil? || !work_access.is_a?(Hash)

      if visibility == 'public' && !audience_subset?(['public'], resource_read_groups)
        errors.add(:work_access, "works can't be public in a restricted collection")
      end
      return unless grants.is_a?(Hash)
      return if audience_subset?(Array(grants['read']), resource_read_groups)

      errors.add(:work_access, "works can't be viewable by a group the collection doesn't grant")
    end
end
