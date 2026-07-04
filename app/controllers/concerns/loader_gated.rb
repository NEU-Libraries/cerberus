# frozen_string_literal: true

# Coarse staff/privileged gate for librarian tooling (batch ingest's role
# floor, reused by the metadata-export surfaces). Mirrors
# LoadersController#require_loader_role: a signed-in user below the loader tier
# gets a 403 forbidden page, not a redirect, so a guessed URL is no wider a door
# than the UI affordance that hides the control.
module LoaderGated
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :require_loader_role
  end

  private

    def require_loader_role
      return if current_user&.loader_tier?

      render template: 'errors/forbidden', status: :forbidden, layout: 'application'
    end
end
