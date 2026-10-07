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

    breadcrumb_for 'Tombstoned items', :admin_tombstones_path

    include Blacklight::Configurable

    copy_blacklight_config_from(CatalogController)

    # The types this registry manages, and the allow-list a `type` param has to
    # be in. Atlas restores and purges any resource through one generic endpoint,
    # so no per-type class is needed, but this still has to refuse a FileSet or
    # a Blob, which have no business being restored from here.
    RESTORABLE_TYPES = %w[Work Collection Community].freeze

    RESTORE_PARENT_TOMBSTONED = 'Restore refused — this item’s parent is still tombstoned. ' \
                                'Restore the parent first, then try again.'

    RESTORE_FAILED = 'Restore could not be completed.'

    PURGED = 'Permanently deleted. The item, its files and every preserved copy are gone; ' \
             'the audit record of the deletion remains.'

    PURGE_FAILED = 'Permanent deletion could not be completed.'

    PURGE_HAS_CHILDREN = 'Permanent deletion refused — this container still has members, ' \
                         'and tombstoned members count. Permanently delete each one first.'

    # One page at the largest page size; a form posting more is not this page.
    BULK_LIMIT = TombstonedItems::PER_PAGE_OPTIONS.max

    def index
      @per_page = TombstonedItems::PER_PAGE_OPTIONS.include?(params[:per_page].to_i) ? params[:per_page].to_i : nil
      @from = parsed_date(params[:from])
      @to = parsed_date(params[:to])
      @response = TombstonedItems.call(scope: self, page: params[:page], query: params[:q],
                                       per_page: @per_page, from: @from, to: @to)
      @parents = StructuralParents.call(documents: @response.documents)
    end

    def restore
      unless restorable_type?
        return redirect_to(admin_tombstones_path, alert: 'Unknown resource type — nothing was restored.')
      end

      case TombstoneRegistryAction.restore(params[:id])
      when :ok
        flash[:notice_link] = { 'label' => 'View it', 'path' => resource_path(params[:type], params[:id]) }
        redirect_to admin_tombstones_path, notice: 'The item has been restored and is now discoverable.'
      when :tombstoned_parent then redirect_to admin_tombstones_path, alert: RESTORE_PARENT_TOMBSTONED
      else redirect_to admin_tombstones_path, alert: RESTORE_FAILED
      end
    end

    def destroy
      unless restorable_type?
        return redirect_to(admin_tombstones_path, alert: 'Unknown resource type — nothing was deleted.')
      end

      redirect_to admin_tombstones_path, **purge_flash(TombstoneRegistryAction.purge(params[:id]))
    end

    # Restore is open to the devolved-admin tier; delete stays :admin only, the
    # same split as the single-item actions above.
    def bulk
      action = params[:bulk_action].to_s
      return require_admin if action == 'delete' && !current_user.admin?

      noids = bulk_noids
      unless TombstoneBulkJob::ACTIONS.include?(action) && noids.any?
        return redirect_to(admin_tombstones_path, alert: 'Select at least one item, then choose an action.')
      end

      TombstoneBulkJob.perform_later(action: action, noids: noids)
      redirect_back_or_to admin_tombstones_path, notice: bulk_notice(action, noids.size)
    end

    private

      def restorable_type?
        RESTORABLE_TYPES.include?(params[:type])
      end

      # A fresh hash each time: redirect_to deletes the flash keys from the hash
      # it is given, so a shared constant would lose its message after one use.
      def purge_flash(outcome)
        case outcome
        when :ok then { notice: PURGED }
        when :has_children then { alert: PURGE_HAS_CHILDREN }
        else { alert: PURGE_FAILED }
        end
      end

      def bulk_noids
        Array(params[:ids]).compact_blank.uniq.first(BULK_LIMIT)
      end

      def parsed_date(value)
        Date.iso8601(value) if value.present?
      rescue Date::Error
        nil
      end

      def bulk_notice(action, count)
        verb = action == 'delete' ? 'Permanent deletion' : 'Restore'
        "#{verb} of #{count} item#{'s' unless count == 1} has started. " \
          'The result will arrive in your inbox and the admin ledger.'
      end
  end
end
