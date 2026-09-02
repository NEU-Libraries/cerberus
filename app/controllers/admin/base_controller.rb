# frozen_string_literal: true

module Admin
  # Shared base for /admin/* surfaces: the role gate and the breadcrumb trail.
  # See docs/admin.md.
  #
  # This class stays :admin-only, so a new /admin/* controller is admin-only
  # unless it deliberately opts out. Do not broaden the gate here.
  class BaseController < ApplicationController
    class_attribute :breadcrumb_label, :breadcrumb_path_helper, instance_writer: false

    before_action :authenticate_user!
    before_action :require_admin
    before_action :build_admin_breadcrumbs

    def self.breadcrumb_for(label, path_helper)
      self.breadcrumb_label = label
      self.breadcrumb_path_helper = path_helper
    end

    private

      def require_admin
        return if current_user&.admin?

        render template: 'errors/forbidden', status: :forbidden, layout: 'application'
      end

      # Opt-in only: a subclass that needs the devolved-admin tier skips
      # `require_admin` and adds this as a before_action instead.
      def require_admin_or_delegate
        return if current_user&.admin? || current_user&.admin_delegate?

        render template: 'errors/forbidden', status: :forbidden, layout: 'application'
      end

      def build_admin_breadcrumbs
        return if is_a?(Admin::DashboardController)

        # `:exact` so the root stays a link on every sub-page — loaf's default
        # inclusive match treats `/admin` as current on all `/admin/*` paths,
        # marking "Administration" as a dead-end rather than a link to the hub.
        breadcrumb 'Administration', admin_root_path, match: :exact
        return if breadcrumb_label.blank?

        # `:exact` so the section stays a link on its sub-pages, where the action
        # adds its own current leaf.
        breadcrumb breadcrumb_label, send(breadcrumb_path_helper), match: :exact
      end
  end
end
