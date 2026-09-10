# frozen_string_literal: true

module Admin
  # Replace a file: find a Work, then replace or roll back one of its Blobs.
  # See docs/admin.md.
  #
  # Reachable by :admin and by the devolved-admin tier — Atlas already grants
  # Blob :update, :rollback and :read_versions to that pair.
  class FilesController < BaseController
    skip_before_action :require_admin
    before_action :require_admin_or_delegate

    include Blacklight::Configurable
    include UploadStaging

    copy_blacklight_config_from(CatalogController)

    breadcrumb_for 'Replace a file', :admin_files_path

    def index
      @results = ResourceSearch.call(scope: self, query: params[:q], types: %w[Work]) if params[:q].present?
    end

    # Content Blobs only. A Delegate carries a `uri` and is derived, so it is
    # rejected here rather than offered for replacement.
    def manage
      breadcrumb 'Manage files', admin_files_manage_path(work_id: params[:work_id])
      @work = AtlasRb::Work.find(params[:work_id])
      raise ResourceNotFound if @work.nil?

      assets  = AtlasRb::Work.assets(params[:work_id]).reject { |asset| asset[:uri].present? }
      history = version_history(assets.map(&:noid))
      @blobs  = assets.map { |asset| { asset: asset, versions: history.fetch(asset.noid, []) } }
    end

    def replace
      file = params[:binary]
      return back_to_manage(alert: 'Choose a file to upload.') if file.blank?

      staged = stage_upload(file, params[:work_id])
      FileReplacementJob.perform_later(params[:blob_noid], params[:work_id], staged,
                                       file.original_filename, SecureRandom.uuid)
      back_to_manage(notice: 'Replacement queued — the new version will appear here once processing finishes.')
    end

    def rollback
      AtlasRb::Blob.rollback(params[:blob_noid], params[:version_id])
      FileDerivativeRefreshJob.perform_later(params[:work_id], params[:blob_noid])
      back_to_manage(notice: "Reverted to #{params[:version_id]} — derivatives are refreshing.")
    end

    private

      # One batched call, not a versions-per-noid fan-out. find_many_versions
      # is unordered and drops an id it cannot resolve, so index by blob_id.
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
