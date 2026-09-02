# frozen_string_literal: true

module Admin
  # On-demand Solr re-projection for a Work or a Set. See docs/admin.md.
  #
  # AtlasRb::System.reindex runs on the Atlas system token with the principal
  # pinned to the system NUID, so Atlas applies no per-user check on this path.
  # The gate here — :admin or the devolved-admin tier — is the only one.
  class ReindexController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    rescue_from AtlasRb::ForbiddenError do
      render template: 'errors/forbidden', status: :forbidden
    end

    # One call, answered inline. Atlas's subtree walk stops at Works, so a
    # subtree reindex here would re-project the same single resource.
    def work
      noid = params[:noid]

      case AtlasRb::System.reindex(noid).status
      when 204 then flash[:notice] = 'Work reindexed.'
      when 404 then flash[:alert]  = "No resource found for #{noid}."
      else          flash[:alert]  = "Reindex of #{noid} failed."
      end

      redirect_to work_path(noid)
    rescue Faraday::Error => e
      flash[:alert] = "Reindex of #{noid} failed: #{e.message}"
      redirect_to work_path(noid)
    end

    # Read the Set before enqueueing, so an unknown or unreadable id fails in
    # front of the person who clicked rather than inside a job.
    def set
      noid = params[:noid]
      compilation = AtlasRb::Compilation.find(noid)
      raise ResourceNotFound if compilation.nil?

      SetReindexJob.perform_later(noid)
      flash[:notice] = "Reindex of “#{compilation['title']}” has started. " \
                       'Your inbox will have the result when it finishes.'
      redirect_to set_path(noid)
    end
  end
end
