# frozen_string_literal: true

module Admin
  # Replace-a-file surface. Non-destructive: replacing a Work's Blob appends a
  # new OCFL version (Blob.update) while preserving the Blob NOID, so prior
  # versions stay retrievable. A finder→manage workflow mirroring
  # LinkedMembersController:
  #
  #   index    → search for the Work
  #   manage   → its replaceable Blobs, each with version history + a replace form
  #   replace  → stage the upload, queue FileReplacementJob, back to manage
  #   rollback → reinstate a prior version (Blob.rollback), refresh derivatives
  #
  # Reachable by :admin and by the devolved-admin tier (User#admin_delegate?) —
  # Atlas's Blob :update/:rollback are already open to :privileged unscoped,
  # and :read_versions (the manage view's version-history listing) is granted
  # to the same :privileged + admin-group pair via apply_admin_delegate_abilities.
  #
  # Version-content streaming (download a superseded version) lives in
  # FileVersionsController, which is ActionController::Live; keeping it separate
  # means the finder/mutation actions here aren't forced into stream semantics.
  # The acting user's NUID flows ambiently (Current.nuid), auto-propagating to
  # the enqueued jobs.
  class FilesController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    include Blacklight::Configurable
    include UploadStaging

    copy_blacklight_config_from(CatalogController)

    breadcrumb_for 'Replace a file', :admin_files_path

    # Step 1 — find the Work.
    def index
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work]) if params[:q].present?
    end

    # The Work's replaceable Blobs (content assets; Delegates carry a uri and are
    # derived, not replaced here), each annotated with its version history.
    def manage
      breadcrumb 'Manage files', admin_files_manage_path(work_id: params[:work_id])
      @work = AtlasRb::Work.find(params[:work_id])
      raise ResourceNotFound if @work.nil?

      assets  = AtlasRb::Work.assets(params[:work_id]).reject { |asset| asset[:uri].present? }
      history = version_history(assets.map(&:noid))
      @blobs  = assets.map { |asset| { asset: asset, versions: history.fetch(asset.noid, []) } }
    end

    # Replace a Blob's bytes with a new upload — a new version, NOID preserved.
    def replace
      file = params[:binary]
      return back_to_manage(alert: 'Choose a file to upload.') if file.blank?

      staged = stage_upload(file, params[:work_id])
      FileReplacementJob.perform_later(params[:blob_noid], params[:work_id], staged,
                                       file.original_filename, SecureRandom.uuid)
      back_to_manage(notice: 'Replacement queued — the new version will appear here once processing finishes.')
    end

    # Revert a Blob to a prior version (non-destructive: rollback re-appends the
    # chosen version's bytes), then refresh derivatives from the reinstated bytes.
    def rollback
      AtlasRb::Blob.rollback(params[:blob_noid], params[:version_id])
      FileDerivativeRefreshJob.perform_later(params[:work_id], params[:blob_noid])
      back_to_manage(notice: "Reverted to #{params[:version_id]} — derivatives are refreshing.")
    end

    private

      # Every replaceable Blob's version history in one call rather than a
      # versions-per-noid fan-out: this page reads every held binary on the
      # Work, which on a multipage Work is one per page. find_many_versions is
      # unordered and drops an id it cannot resolve, so index by blob_id; a
      # dropped id renders as a file with no version table, which is what a
      # failed history read already did.
      def version_history(blob_noids)
        return {} if blob_noids.empty?

        AtlasRb::Blob.find_many_versions(blob_noids)
                     .to_h { |envelope| [envelope['blob_id'], Array(envelope['versions'])] }
      end

      def back_to_manage(flash_opts)
        redirect_to admin_files_manage_path(work_id: params[:work_id]), **flash_opts
      end
  end
end
