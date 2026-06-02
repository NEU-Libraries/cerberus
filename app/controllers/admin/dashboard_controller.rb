# frozen_string_literal: true

module Admin
  # Admin actions hub — the /admin landing page. A small console of
  # repository-structure operations (re-parent, linked members) that
  # apply repository-wide and so live behind the :admin gate inherited
  # from Admin::BaseController. The cards are the entry points; each
  # action's workflow lives on its own surface.
  class DashboardController < BaseController
    def index; end
  end
end
