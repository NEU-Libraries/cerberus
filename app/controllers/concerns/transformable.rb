# frozen_string_literal: true

# The shared #update for the Work/Collection/Community Metadata, Permissions
# and Advanced tabs — separate forms that PATCH one action with disjoint
# fields. See docs/edit-surfaces.md.
module Transformable
  extend ActiveSupport::Concern

  include AtlasWrite
  include PermissionsForm
  include DescriptiveMetadata
  include AdvancedMetadata

  # The resource's raw MODS, read once per request. Read paths only:
  # #save_descriptive! deliberately re-reads inside with_stale_retry, because a
  # retry needs the current MODS and its lock token, not a memo from earlier.
  def resource_mods(klass)
    @resource_mods ||= AtlasRb.const_get(klass).mods(params[:id], 'xml')
  end

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

  # @permissions is the resource's CURRENT envelope, loaded by the authorization
  # gate; it is what tells ResourcePermissions whether this submit narrows.
  def apply_permissions(klass, id, resource_key)
    report(ResourcePermissions.new(klass: klass, id: id, envelope: permission_params(resource_key),
                                   current_read: Array(@permissions&.read), actor: current_user).apply!)
  end

  # No current_read: one line after a create, @permissions still holds the
  # DESTINATION's envelope, so it would answer the wrong question.
  def apply_new_permissions(klass, id, resource_key)
    report(ResourcePermissions.new(klass: klass, id: id,
                                   envelope: permission_params(resource_key), actor: current_user).apply_minted!)
  end

  private

    def report(result)
      flash[result.level] = result.message if result.level
    end
end
