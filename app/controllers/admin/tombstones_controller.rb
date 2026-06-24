# frozen_string_literal: true

module Admin
  # Restore-a-withdrawal surface. The admin-only counterpart to the tombstone
  # ("Delete") action on the show pages: it lists every withdrawn Work,
  # Collection and Community, and reverses a withdrawal on request.
  #
  # atlas_rb already ships the backend wiring — AtlasRb::Admin::{Work,Collection,
  # Community}.restore — under its operator-only Admin namespace; this is purely
  # the Cerberus consumer. Restore is reversible (re-tombstone), so unlike the
  # Admin destroy path it needs no confirm marker. The acting admin's NUID flows
  # to Atlas ambiently (config/initializers/atlas_rb.rb wires Current.nuid), which
  # both passes Atlas's authz and stamps the restore audit event the History tab
  # already renders.
  class TombstonesController < BaseController
    # Borrow CatalogController's Solr config so TombstonedItems' SearchBuilder
    # behaves like the catalog's (same pattern as ReparentController).
    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # Resource class => the atlas_rb Admin class that restores it. Also the
    # allow-list: a `type` param outside these keys is rejected.
    RESTORERS = {
      'Work'       => AtlasRb::Admin::Work,
      'Collection' => AtlasRb::Admin::Collection,
      'Community'  => AtlasRb::Admin::Community
    }.freeze

    RESTORE_FAILED = 'Restore could not be completed — a withdrawn parent must be ' \
                     'restored first. Restore that, then try again.'

    def index
      @response = TombstonedItems.call(scope: self, page: params[:page])
    end

    def restore
      restorer = RESTORERS[params[:type]]
      return redirect_to(admin_tombstones_path, alert: 'Unknown resource type — nothing was restored.') if restorer.nil?

      if restored?(restorer)
        redirect_to admin_tombstones_path, notice: 'Withdrawal reversed — the item is live again.'
      else
        redirect_to admin_tombstones_path, alert: RESTORE_FAILED
      end
    rescue Faraday::Error => e
      Rails.logger.error("Admin::TombstonesController#restore: #{e.class} #{e.message}")
      redirect_to admin_tombstones_path, alert: RESTORE_FAILED
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
  end
end
