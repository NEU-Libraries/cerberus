# frozen_string_literal: true

module Admin
  # Shared base for admin-only surfaces. Anything mounted under
  # /admin/* should inherit from this so the role gate stays
  # consistent. :admin role is the only tier that passes —
  # :privileged is staff capability, not admin.
  #
  # It also owns the shared breadcrumb trail (Administration / <section>). A
  # subclass declares its section via `breadcrumb_for` (label + index path
  # helper); BaseController prepends the "Administration" root. The dashboard
  # (the hub itself) declares nothing, so it shows no breadcrumb. Sub-pages
  # (new / edit / manage / …) add their own leaf crumb in the action. Each admin
  # view renders the trail via `= render 'admin/breadcrumb_header'` (the proven
  # per-view :container_header pattern — a custom admin layout double-renders the
  # view through Blacklight's layout).
  class BaseController < ApplicationController
    class_attribute :breadcrumb_label, :breadcrumb_path_helper, instance_writer: false

    before_action :authenticate_user!
    before_action :require_admin
    before_action :build_admin_breadcrumbs

    # Declare the admin section's breadcrumb: its label and the route helper for
    # its landing page (e.g. `breadcrumb_for 'Replace a file', :admin_files_path`).
    def self.breadcrumb_for(label, path_helper)
      self.breadcrumb_label = label
      self.breadcrumb_path_helper = path_helper
    end

    private

      def require_admin
        return if current_user&.admin?

        render template: 'errors/forbidden', status: :forbidden, layout: 'application'
      end

      def build_admin_breadcrumbs
        return if is_a?(Admin::DashboardController)

        # `:exact` so the root stays a link on every sub-page — without it, loaf's
        # default inclusive match treats `/admin` as current on all `/admin/*` paths,
        # marking "Administration" as the current crumb (a dead-end, not a link back
        # to the hub). The dashboard is excluded above, so it is never the current page.
        breadcrumb 'Administration', admin_root_path, match: :exact
        return if breadcrumb_label.blank?

        # `:exact` so the section stays a link on its sub-pages (new/edit/manage),
        # where the action adds its own current leaf.
        breadcrumb breadcrumb_label, send(breadcrumb_path_helper), match: :exact
      end
  end
end
