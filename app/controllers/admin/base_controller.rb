# frozen_string_literal: true

module Admin
  # Shared base for admin-only surfaces. Anything mounted under
  # /admin/* should inherit from this so the role gate stays
  # consistent. :admin role is the only tier that passes —
  # :privileged is staff capability, not admin.
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    private

      def require_admin
        return if current_user&.admin?

        render template: 'errors/forbidden', status: :forbidden, layout: 'application'
      end
  end
end
