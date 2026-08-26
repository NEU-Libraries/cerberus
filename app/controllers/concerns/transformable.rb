# frozen_string_literal: true

# The shared #update entry point for the Work, Collection and Community
# Metadata, Permissions and Advanced tabs — separate forms that all PATCH the
# same action with disjoint fields.
#
# Each piece it composes owns one half of a job: PermissionsForm parses and
# presents the permissions form while ResourcePermissions writes it,
# DescriptiveMetadata and AdvancedMetadata merge MODS, and AtlasWrite makes a
# write survive the wire. What is left here is the routing between them.
module Transformable
  extend ActiveSupport::Concern

  include AtlasWrite
  include PermissionsForm
  include DescriptiveMetadata
  include AdvancedMetadata

  # The resource's raw MODS, read once per request.
  #
  # Both form loaders parse the same document — DescriptiveMetadata for the bare
  # title/abstract/keywords, AdvancedMetadata for the structured title parts and
  # names — and the Work edit page runs both, so without this the page fetched
  # the same XML from Atlas twice.
  #
  # Read paths only. The write path in #save_descriptive! deliberately re-reads
  # inside with_stale_retry, because a retry has to pick up the current MODS and
  # its lock token; handing it a memo from earlier in the request would defeat
  # the retry.
  def resource_mods(klass)
    @resource_mods ||= AtlasRb.const_get(klass).mods(params[:id], 'xml')
  end

  # Shared #update handler for the Work/Collection/Community Metadata + Permissions
  # tabs (separate forms, both PATCH #update with disjoint fields). Permissions go
  # to Atlas's metadata endpoint; descriptive fields are validated then merged
  # into the existing MODS and written via the structure-safe raw `update` path.
  def handle_metadata_update(klass:, resource_key:, keywords:)
    id = params[:id]
    show_path = public_send("#{klass.downcase}_path", id)

    if advanced_submitted?(resource_key)
      save_advanced!(klass, id, **advanced_params(resource_key))
      return redirect_to(show_path)
    end

    apply_permissions(klass, id, resource_key)
    apply_thumbnail(klass, id)
    return redirect_to(show_path) unless descriptive_submitted?(resource_key)

    apply_descriptive(klass, id, resource_key, keywords, show_path)
  end

  # The edit path's ACL write. @permissions is the resource's current envelope,
  # loaded by the authorization gate, and it is what tells ResourcePermissions
  # whether this submit takes audience away.
  def apply_permissions(klass, id, resource_key)
    report(ResourcePermissions.new(klass: klass, id: id, envelope: permission_params(resource_key),
                                   current_read: Array(@permissions&.read), actor: current_user).apply!)
  end

  # The create path's ACL write. No current_read is passed: one line after a
  # create, @permissions still holds the DESTINATION's envelope rather than this
  # resource's, so it would answer the wrong question.
  def apply_new_permissions(klass, id, resource_key)
    report(ResourcePermissions.new(klass: klass, id: id,
                                   envelope: permission_params(resource_key), actor: current_user).apply_minted!)
  end

  private

    def report(result)
      flash[result.level] = result.message if result.level
    end
end
