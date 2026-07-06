# frozen_string_literal: true

# Personal-access token lifecycle for the My DRS "Programmatic access" section.
# A signed-in member of the API group mints / regenerates / revokes the 1-week
# JWT they export as ATLAS_JWT to drive the Atlas API headless (atlas_rb's
# BYO-JWT mode).
#
# Minting a token for an NUID is a "become anyone" operation — which is why
# Atlas :system-gates it — so Cerberus only ever mints for the *real* signed-in
# user (current_user, never the view-as effective_user) and never persists the
# token: it's rendered into the response once and dropped, so a leaked
# session/DB never carries the credential.
class AtlasTokensController < ApplicationController
  before_action :require_api_access!

  # Mint a token and reveal it once. `regenerate` first revokes any outstanding
  # tokens (jti rotation) so the freshly-minted one is the only valid credential.
  def create
    AtlasRb::System::Token.revoke(nuid: current_user.nuid) if params[:regenerate].present?
    token = AtlasRb::System::Token.mint(nuid: current_user.nuid)

    render_section(token:  token,
                   notice: token ? nil : "We couldn't mint a token for your account.")
  end

  # Revoke every outstanding token for the user (all-or-nothing jti rotation).
  def destroy
    AtlasRb::System::Token.revoke(nuid: current_user.nuid)
    render_section(notice: 'All personal-access tokens revoked.')
  end

  private

    # Render the section partial as the response. Its buttons live inside a
    # <turbo-frame id="atlas_token">, so Turbo swaps the frame in place — no
    # full-page re-render (which would mean re-running the My DRS dashboard
    # queries) and no secret routed through the flash / DB session.
    def render_section(token: nil, notice: nil)
      render partial: 'my_drs/programmatic_access',
             locals:  { token: token, notice: notice }
    end

    # Self-service surface: gate on the *real* user (current_user) — an admin in
    # a view-as session must not be able to mint the target's personal
    # credential. Non-members (including the logged-out) get the shared 403 via
    # Authorizable's rescue_from CanCan::AccessDenied.
    def require_api_access!
      raise CanCan::AccessDenied unless current_user&.member_of?(Permissions::API_GROUP)
    end
end
