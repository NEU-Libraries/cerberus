# frozen_string_literal: true

# The Captions section: what the page shows for an existing caption, and what a
# submitted .vtt does next. The upload is staged and handed to CaptionJob rather
# than written here, because the job has to wait for the primary file to land
# first — both claim the original_file role, and the loser is discarded.
module WorkCaptions
  extend ActiveSupport::Concern

  private

    # State for the Captions section. `files` is absent at deposit, where the Work
    # has no assets yet and so can have no caption to link to.
    def load_caption!(offered:, files: nil)
      @caption_offered = offered
      @caption = CaptionTrack.for(files)
    end

    # Stage a caption upload and hand it to CaptionJob, if this form carried one.
    #
    # A refused format flashes and carries on rather than raising, for the same
    # reason apply_permissions does: this runs after the descriptive save, and the
    # title and abstract edits that came with it are valid and already written.
    def apply_caption!
      file = params[:caption]
      return if file.blank?
      return flash[:alert] = CaptionTrack::REFUSED unless CaptionTrack.accepted?(file.original_filename)

      CaptionJob.perform_later(params[:id], stage_upload(file, params[:id]),
                               file.original_filename, SecureRandom.uuid)
    end
end
