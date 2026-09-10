# frozen_string_literal: true

# One v1 Fedora pid and the v2 NOID it became at migration. v1 pids are not
# carried onto v2 objects — the pid was Fedora's plumbing, not the object's
# identity — so this table is the only place the correspondence exists. Losing
# it costs link convenience and nothing else: it is rebuilt from the migration
# mapping, never reconstructed from the objects, which do not know their pids.
#
# Two consumers read it. LegacyController turns an inbound v1 URL into a
# redirect, and the impressions historical import joins ten years of v1 rows
# onto their v2 objects through the same map.
#
# Written once by the migration and thereafter read-only, which is what makes it
# safe to cache and leaves it with no consistency surface.
class LegacyIdentifier < ApplicationRecord
  # The v2 object kinds a v1 pid can name. The value drives which route
  # LegacyController builds, so it is a closed set rather than free text — an
  # unrecognised type would otherwise reach the router as a nil path helper.
  OBJECT_TYPES = %w[community collection work download set].freeze

  validates :pid, presence: true, uniqueness: true
  validates :noid, presence: true
  validates :object_type, presence: true, inclusion: { in: OBJECT_TYPES }

  # The lookup the request path makes, against the unique index on pid.
  #
  # @param pid [String] the full v1 pid, `neu:` prefix included
  # @return [LegacyIdentifier, nil]
  def self.for_pid(pid)
    return nil if pid.blank?

    find_by(pid: pid)
  end
end
