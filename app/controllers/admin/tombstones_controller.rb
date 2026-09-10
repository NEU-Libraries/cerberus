# frozen_string_literal: true

module Admin
  # The tombstone registry: list a tombstoned item, restore it, or delete it
  # permanently. See docs/admin.md.
  #
  # Two gates, mirroring Atlas. Index and restore take :admin or the
  # devolved-admin tier; destroy is :admin only, because Atlas's
  # apply_admin_delegate_abilities omits :destroy. Gating destroy any wider here
  # only buys a 403 from the far end.
  class TombstonesController < BaseController
    skip_before_action :require_admin, except: [:destroy]
    before_action :require_admin_or_delegate, except: [:destroy]

    breadcrumb_for 'Restore a tombstoned item', :admin_tombstones_path

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

      # Restore is not one of atlas_rb's typed-error paths, so a non-2xx comes
      # back as a plain Faraday::Response instead of raising. Drop the success?
      # check and a refused restore reports as done.
      def restored?(restorer)
        response = restorer.restore(params[:id])
        !response.respond_to?(:success?) || response.success?
      end

      # Destroy sits outside atlas_rb's typed-error middleware too, so the
      # container refusal arrives as a plain 422 and has to be read off the
      # body. It is the one failure the admin can act on.
      def purge_outcome(purger)
        response = purger.destroy(params[:id], confirm: :i_understand)
        return { notice: PURGED } if !response.respond_to?(:success?) || response.success?
        return { alert: PURGE_HAS_CHILDREN } if purge_error_code(response) == 'has_children'

        { alert: PURGE_FAILED }
      end

      # Atlas's refusal envelope carries the human message on `error` and the
      # machine token on `code` — the reverse of the re-parent and linked-member
      # envelopes, so read `code` here, not the typed errors' discriminator.
      def purge_error_code(response)
        body = JSON.parse(response.body.to_s)
        body['code'] if body.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
  end
end
