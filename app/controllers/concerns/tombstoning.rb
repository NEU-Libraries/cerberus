# frozen_string_literal: true

# The tombstone ("Delete") action shared by the Work, Collection and Community
# controllers, and the removal reason it records. See docs/authorization.md and
# docs/admin.md.
module Tombstoning
  extend ActiveSupport::Concern

  included do
    helper_method :chooses_removal_reason?
  end

  private

    # Withdraw the resource and report the outcome. atlas_rb does NOT raise on
    # the tombstone refusal — RaiseOnResourceError passes the 422 (`code:
    # "has_live_children"`) straight through as a raw Faraday::Response, so the
    # status has to be read. Ignoring it reports a false "deleted" while the
    # resource stays live. See docs/authorization.md.
    # return_to lets a list that offers the delete (deposit triage, My DRS) take
    # the user back to itself. url_from drops any off-host value, so it cannot
    # become an open redirect.
    def perform_tombstone!
      landing = url_from(params[:return_to]) || parent_path(params[:id])
      response = AtlasRb::Resource.tombstone(params[:id], reason: removal_reason)
      if response.success?
        redirect_to landing, notice: "#{solr_type} deleted."
      elsif response.status == 422
        redirect_back_or_to(root_path, alert: tombstone_refusal(response))
      else
        redirect_back_or_to(root_path, alert: "#{solr_type} could not be deleted.")
      end
    end

    # Only the admin tier chooses the removal note. Anyone else withdrawing an
    # item records the curator's note, whatever the form sent. A request with no
    # reason is a cancelled deposit, which was never published and records none.
    def removal_reason
      return if params[:reason].blank?

      chooses_removal_reason? ? params[:reason] : TombstoneReasons::CURATOR
    end

    def chooses_removal_reason?
      effective_user&.admin? || effective_user&.admin_delegate?
    end

    def tombstone_refusal(response)
      if tombstone_refusal_code(response) == 'invalid_reason'
        "#{solr_type} could not be deleted. Choose one of the listed removal reasons."
      else
        "#{solr_type} can't be deleted while it still contains live members. Withdraw or move them first."
      end
    end

    def tombstone_refusal_code(response)
      JSON.parse(response.body.to_s)['code']
    rescue JSON::ParserError
      nil
    end
end
