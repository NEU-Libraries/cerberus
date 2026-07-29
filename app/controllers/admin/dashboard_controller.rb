# frozen_string_literal: true

module Admin
  # Admin actions hub — the /admin landing page. A small console of
  # repository-structure operations that apply repository-wide. Reachable
  # by :admin and by the devolved-admin tier (User#admin_delegate?); the
  # view itself decides which cards each visitor sees — see
  # app/views/admin/dashboard/index.html.haml. The cards are the entry
  # points; each action's workflow lives on its own surface, gated the same
  # broadened way.
  class DashboardController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    def index; end
  end
end
