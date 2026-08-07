# frozen_string_literal: true

module Admin
  # On-demand Solr re-projection, reachable by :admin and by the devolved-admin
  # tier (User#admin_delegate?). The buttons sit on the Work and Set show pages,
  # because that is where someone notices a record has gone stale, but the
  # actions are mounted here so the role gate stays in one place.
  #
  # That placement is load-bearing rather than tidy: AtlasRb::System.reindex
  # runs on the Atlas system token with the principal pinned to the system
  # NUID, so Atlas applies no per-user check on this path. The gate here is the
  # only thing standing in front of it.
  #
  # A reindex re-derives a resource's Solr doc from Atlas's authoritative store.
  # It is Solr-only — no lifecycle transition, no audit event, no minting — and
  # idempotent, so a double-click costs time and nothing else.
  class ReindexController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    # A private Set the caller may not read: Atlas says 403, the user sees the
    # standard forbidden page. Mirrors SetsController, which is the surface the
    # Set button is reached from.
    rescue_from AtlasRb::ForbiddenError do
      render template: 'errors/forbidden', status: :forbidden
    end

    # One Work, answered inline — it is a single call. Atlas's subtree walk
    # (SubtreeResourcesQuery) stops at Works and never descends into FileSets,
    # so a subtree call here would reindex the same one resource.
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

    # A Set names collections whose subtrees can run to thousands of resources,
    # so this only enqueues. The Set is read first so an unknown or unreadable
    # id fails here, in front of the person who clicked, rather than inside a
    # job nobody is watching.
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
