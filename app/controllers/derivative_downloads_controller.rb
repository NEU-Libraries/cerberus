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

    deny_if_embargoed!(params[:work_id])
    authorize! :read, derivative_tier_document(delegate)
    redirect_to download_url_for(delegate), allow_other_host: true, status: :found
  end

  private

    # A control labelled Download has to download. The redirect lands on
    # Cantaloupe, so the browser obeys *its* headers, not ours: a `download`
    # attribute on the link is ignored across origins, and without a disposition
    # the JPEG simply renders in a new tab — leaving the master row saving a file
    # and the size rows opening a viewer, from one list, under one word.
    #
    # Cantaloupe reads `response-content-disposition`, and appending it after
    # signing is safe because the HMAC covers the request PATH only (see
    # IiifSigner) — the query string is not part of the message.
    def download_url_for(delegate)
      "#{IiifSigner.sign_url(delegate['uri'])}&response-content-disposition=" \
        "#{CGI.escape(ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment',
                                                                      filename: derivative_filename(delegate)))}"
    end

    # Mirrors the master row's `master_<noid>.jpg`: the tier, then the work, so
    # three tiers of three works don't collide in one Downloads folder. The
    # tier slug matches the zip entry names ZipEntryWriter writes.
    def derivative_filename(delegate)
      slug = delegate['use'].to_s.parameterize.presence || 'derivative'
      "#{slug}_#{params[:work_id]}.jpg"
    end
end
