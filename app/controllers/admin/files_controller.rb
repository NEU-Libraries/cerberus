# frozen_string_literal: true

module Admin
  # Replace-a-file surface. Admin-only, non-destructive: replacing a Work's Blob
  # appends a new OCFL version (Blob.update) while preserving the Blob NOID, so
  # prior versions stay retrievable. A finder→manage workflow mirroring
  # LinkedMembersController:
  #
  #   index    → search for the Work
  #   manage   → its replaceable Blobs, each with version history + a replace form
  #   replace  → stage the upload, queue FileReplacementJob, back to manage
  #   rollback → reinstate a prior version (Blob.rollback), refresh derivatives
  #
  # Version-content streaming (download a superseded version) lives in
  # FileVersionsController, which is ActionController::Live; keeping it separate
  # means the finder/mutation actions here aren't forced into stream semantics.
  # The acting admin's NUID flows ambiently (Current.nuid), auto-propagating to
  # the enqueued jobs.
  class FilesController < BaseController
    include Blacklight::Configurable
    include UploadStaging

    copy_blacklight_config_from(CatalogController)

    # Step 1 — find the Work.
    def index
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work]) if params[:q].present?
    end

    # The Work's replaceable Blobs (content assets; Delegates carry a uri and are
    # derived, not replaced here), each annotated with its version history.
    def manage
      @work = AtlasRb::Work.find(params[:work_id])
      raise ResourceNotFound if @work.nil?

      @blobs = AtlasRb::Work.assets(params[:work_id])
                            .reject { |asset| asset[:uri].present? }
                            .map { |asset| { asset: asset, versions: versions_for(asset.noid) } }
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

      def versions_for(blob_noid)
        Array(AtlasRb::Blob.versions(blob_noid)['versions'])
      end

      def back_to_manage(flash_opts)
        redirect_to admin_files_manage_path(work_id: params[:work_id]), **flash_opts
      end
  end
end
