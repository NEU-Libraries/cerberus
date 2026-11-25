# frozen_string_literal: true

# Stages a browser upload to local disk so a background job can read it after
# the request ends. Shared by every action that takes a file, so the staging
# path cannot drift between them. Namespaced by a scope id (the Work NOID, or a
# LoadReport's) under the configured uploads root; the original filename is
# preserved as the basename. See docs/uploads.md.
module UploadStaging
  extend ActiveSupport::Concern

  private

    # The form's file, whichever way it came: in the multipart body, or ahead
    # of the form over TUS, when the form carries only `tus_upload_id`.
    def submitted_file(multipart)
      return multipart if multipart.present?

      TusStore.claim(params[:tus_upload_id], owner_id: current_user&.nuid)
    end

    def stage_upload(file, scope_id)
      place_upload(file, File.join(Rails.application.config.x.cerberus.uploads_root, scope_id.to_s))
    end

    # FileUtils.cp against the Rack tempfile path is a streaming copy; never
    # File.write(file.read), which would read the whole file into memory.
    def place_upload(file, dir)
      Outage.guard_storage do
        FileUtils.mkdir_p(dir)
        dest = File.join(dir, file.original_filename)
        next file.move_to(dest) if file.respond_to?(:move_to)

        FileUtils.cp(file.tempfile.path.presence || file.path, dest)
        dest
      end
    end
end
