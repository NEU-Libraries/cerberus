# frozen_string_literal: true

# The shared #update for the Work/Collection/Community Metadata, Permissions
# and Advanced tabs — separate forms that PATCH one action with disjoint
# fields. The type, the form key and the two paths all come from the
# controller's own `atlas_resource` declaration. See docs/edit-surfaces.md.
module Transformable
  extend ActiveSupport::Concern

  include AtlasResourceType
  include AtlasWrite
  include PermissionsForm
  include DescriptiveMetadata
  include AdvancedMetadata

  # The resource's raw MODS, read once per request. Read paths only:
  # #save_descriptive! deliberately re-reads inside with_stale_retry, because a
  # retry needs the current MODS and its lock token, not a memo from earlier.
  def resource_mods
    @resource_mods ||= atlas_class.mods(params[:id], 'xml')
  end

  # `include_advanced` says this form carries the Advanced field set INLINE,
  # beside the descriptive fields, rather than on its own tab — the deposit
  # page. It stays an argument because it is a fact about the form that was
  # rendered, not about the type: the Advanced tab's own marker means the
  # opposite thing (advanced fields and nothing else), and confusing the two
  # would make a deposit submit skip its keywords, permissions and confirmation.
  def handle_metadata_update(keywords:, include_advanced: false)
    id = params[:id]

    if advanced_submitted?
      save_advanced!(id, **advanced_params)
      return redirect_to(show_path(id))
    end

    apply_permissions(id)
    apply_thumbnail(id)
    return redirect_to(show_path(id)) unless descriptive_submitted?

    advanced = advanced_params if include_advanced
    apply_descriptive(id, keywords: keywords, advanced: advanced)
  end

  # @permissions is the resource's CURRENT envelope, loaded by the authorization
  # gate; it is what tells ResourcePermissions whether this submit narrows.
  def apply_permissions(id)
    report(ResourcePermissions.new(klass: atlas_class, id: id, envelope: permission_params,
                                   current_read: Array(@permissions&.read), actor: current_user).apply!)
  end

  # No current_read: one line after a create, @permissions still holds the
  # DESTINATION's envelope, so it would answer the wrong question.
  def apply_new_permissions(id)
    report(ResourcePermissions.new(klass: atlas_class, id: id,
                                   envelope: permission_params, actor: current_user).apply_minted!)
  end

  private

    def report(result)
      flash[result.level] = result.message if result.level
    end
end
