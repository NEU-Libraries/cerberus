# frozen_string_literal: true

# Authorized delivery of a Work's gated image derivatives (small/medium/large).
# Their Delegate URIs live on the gated Cantaloupe host, which serves only a
# signed request — so rather than link them directly, the downloads UI routes
# each tier through here: re-read the tier's per-viewer gate, authorize the
# effective user against it (reusing the app's :read Ability via
# DerivativesHelper), then 302 to a short-lived signed URL whose signature
# binds the size (no editing up to full/max). Deep-zoom (the service tier) is a
# cookie flow, not a download, and is handled separately.
class DerivativeDownloadsController < ApplicationController
  include DerivativesHelper

  def show
    delegate = AtlasRb::Work.assets(params[:work_id], nuid: effective_user&.nuid)
                            .find { |asset| asset['use'] == params[:use] && asset['uri'].present? }
    raise Authorizable::ResourceNotFound if delegate.nil?

    authorize! :read, derivative_tier_document(delegate)
    redirect_to IiifSigner.sign_url(delegate['uri']), allow_other_host: true, status: :found
  end
end
