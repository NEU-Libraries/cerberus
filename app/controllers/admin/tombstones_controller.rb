# frozen_string_literal: true

module Admin
  # The tombstone registry — the admin-only counterpart to the tombstone
  # ("Delete") action on the show pages. It lists every tombstoned Work,
  # Collection and Community, and offers the two ways out: reverse the
  # withdrawal, or finish it permanently.
  #
  # Two gates, not one, mirroring Atlas's Ability exactly. Listing and restoring
  # are reachable by :admin and by the devolved-admin tier (User#admin_delegate?):
  # restoring is an operator-level lifecycle action, so it sits with :reparent
  # rather than with edit rights, and Atlas grants :restore to both
  # (apply_admin_delegate_abilities) while withholding it from group-ACL editors
  # and depositors. Permanent deletion is :admin only — Atlas's
  # apply_admin_delegate_abilities deliberately omits :destroy, so gating it any
  # wider here would only produce a 403 from the far end.
  #
  # atlas_rb ships the backend wiring for both verbs under its operator-only
  # Admin namespace; this is purely the Cerberus consumer. The acting user's NUID
  # flows to Atlas ambiently (config/initializers/atlas_rb.rb wires Current.nuid),
  # which both passes Atlas's authz and stamps the audit event. Restore is
  # reversible (re-tombstone) so it needs no confirm marker; destroy is not, and
  # atlas_rb makes that explicit with `confirm: :i_understand`.
  class TombstonesController < BaseController
    skip_before_action :require_admin, except: [:destroy]
    before_action :require_admin_or_delegate, except: [:destroy]

    breadcrumb_for 'Restore a tombstoned item', :admin_tombstones_path

    # Borrow CatalogController's Solr config so TombstonedItems' SearchBuilder
    # behaves like the catalog's (same pattern as ReparentController).
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # Resource class => the atlas_rb Admin class that restores and purges it.
    # Also the allow-list: a `type` param outside these keys is rejected.
    RESOURCE_ADMINS = {
      'Work'       => AtlasRb::Admin::Work,
      'Collection' => AtlasRb::Admin::Collection,
      'Community'  => AtlasRb::Admin::Community
    }.freeze

    RESTORE_FAILED = 'Restore could not be completed — a tombstoned parent must be ' \
                     'restored first. Restore that, then try again.'

    PURGED = 'Permanently deleted. The item, its files and every preserved copy are gone; ' \
             'the audit record of the deletion remains.'

    PURGE_FAILED = 'Permanent deletion could not be completed.'

    # Atlas counts tombstoned members here, unlike the tombstone refusal, which
    # counts only live ones — a purge cannot be undone, so a member left behind
    # is orphaned for good. Say so, because "empty it first" reads as already
    # done to an admin looking at a container whose children are all withdrawn.
    PURGE_HAS_CHILDREN = 'Permanent deletion refused — this container still has members, ' \
                         'and tombstoned members count. Permanently delete each one first.'

    def index
      @response = TombstonedItems.call(scope: self, page: params[:page])
    end

    def restore
      restorer = RESOURCE_ADMINS[params[:type]]
      return redirect_to(admin_tombstones_path, alert: 'Unknown resource type — nothing was restored.') if restorer.nil?

      if restored?(restorer)
        redirect_to admin_tombstones_path, notice: 'Tombstone reversed — the item is live again.'
      else
        redirect_to admin_tombstones_path, alert: RESTORE_FAILED
      end
    rescue Faraday::Error => e
      Rails.logger.error("Admin::TombstonesController#restore: #{e.class} #{e.message}")
      redirect_to admin_tombstones_path, alert: RESTORE_FAILED
    end

    def destroy
      purger = RESOURCE_ADMINS[params[:type]]
      return redirect_to(admin_tombstones_path, alert: 'Unknown resource type — nothing was deleted.') if purger.nil?

      redirect_to admin_tombstones_path, **purge_outcome(purger)
    rescue Faraday::Error => e
      Rails.logger.error("Admin::TombstonesController#destroy: #{e.class} #{e.message}")
      redirect_to admin_tombstones_path, alert: PURGE_FAILED
    end

    private

      # Restore is not one of atlas_rb's typed-error paths (reparent / linked /
      # Compilation / upload), so a non-2xx response flows back as a plain
      # Faraday::Response rather than raising — hence the explicit success? check.
      # A value that doesn't respond to success? is treated as a success; a
      # transport-level failure (host down) still raises Faraday::Error.
      def restored?(restorer)
        response = restorer.restore(params[:id])
        !response.respond_to?(:success?) || response.success?
      end

      # The flash for one purge attempt. Destroy sits outside atlas_rb's
      # typed-error middleware for the same reason restore does, so the
      # container refusal arrives as a plain 422 response and has to be read off
      # the body. It earns its own message because it is the one failure the
      # admin can act on; everything else (404, 403, a transport fault) is the
      # generic alert.
      def purge_outcome(purger)
        response = purger.destroy(params[:id], confirm: :i_understand)
        return { notice: PURGED } if !response.respond_to?(:success?) || response.success?
        return { alert: PURGE_HAS_CHILDREN } if purge_error_code(response) == 'has_children'

        { alert: PURGE_FAILED }
      end

      # Atlas's refusal envelope puts the human message on `error` and the
      # machine token on `code` — the opposite of the re-parent and
      # linked-member envelopes, so read `code` here rather than the
      # discriminator the typed errors key on.
      def purge_error_code(response)
        body = JSON.parse(response.body.to_s)
        body['code'] if body.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
  end
end
