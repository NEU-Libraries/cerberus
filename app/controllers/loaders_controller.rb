# frozen_string_literal: true

# The "My Loaders" interstitial: the Loaders this user's Grouper groups
# unlock, each launching into its nested loads pages. Only the coarse role
# gate lives here — per-loader group enforcement stays in LoadsController,
# so a guessed URL is no wider a door than it ever was.
class LoadersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_loader_role

  def index
    @loaders = Loader.available_to(current_user)
  end

  private

    def require_loader_role
      return if current_user&.loader_tier?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end
end
