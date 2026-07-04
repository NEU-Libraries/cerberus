# frozen_string_literal: true

# Stages a browser upload to local disk so a background job can read it after
# the request ends. Shared by the single-file deposit (WorksController) and the
# admin "replace a file" surface (Admin::FilesController) — one staging path so
# the two can't drift. Namespaced by a scope id (the Work NOID) under the
# configured uploads root; the original filename is preserved as the basename.
module UploadStaging
  extend ActiveSupport::Concern

  private

    def stage_upload(file, scope_id)
      dir = File.join(Rails.application.config.x.cerberus.uploads_root, scope_id.to_s)
      FileUtils.mkdir_p(dir)
      dest = File.join(dir, file.original_filename)
      FileUtils.cp(file.tempfile.path.presence || file.path, dest)
      dest
    end
end
