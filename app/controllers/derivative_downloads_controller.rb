# frozen_string_literal: true

# Authorized delivery of a Work's gated image derivatives (small/medium/large):
# re-read the tier's gate, then 302 to a short-lived signed URL whose signature
# binds the size. See docs/downloads.md.
class DerivativeDownloadsController < ApplicationController
  include DerivativesHelper

  def show
    delegate = AtlasRb::Work.assets(params[:work_id], nuid: effective_user&.nuid)
                            .find { |asset| asset['use'] == params[:use] && asset['uri'].present? }
    raise Authorizable::ResourceNotFound if delegate.nil?

    authorize_tier!(delegate)
    redirect_to download_url_for(delegate), allow_other_host: true, status: :found
  end

  private

    def authorize_tier!(delegate)
      deny_if_unfinished_work!(params[:work_id])
      deny_if_embargoed!(params[:work_id])
      authorize! :read, derivative_tier_document(delegate)
    end

    # The redirect lands on Cantaloupe, so only ITS disposition header makes the
    # browser save rather than render. Appending the parameter after signing is
    # safe because the HMAC covers the request PATH only (see IiifSigner).
    def download_url_for(delegate)
      "#{IiifSigner.sign_url(delegate['uri'])}&response-content-disposition=" \
        "#{CGI.escape(ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment',
                                                                      filename:    derivative_filename(delegate)))}"
    end

    def derivative_filename(delegate)
      slug = delegate['use'].to_s.parameterize.presence || 'derivative'
      "#{slug}_#{params[:work_id]}.jpg"
    end
end
