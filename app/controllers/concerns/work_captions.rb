# frozen_string_literal: true

# The Captions section: what the page shows for a Work's captions, and what a
# submitted .vtt does next. The upload is staged and handed to CaptionJob rather
# than written here, because the job has to wait for the primary file to land
# first — both claim the original_file role, and the loser is discarded.
module WorkCaptions
  extend ActiveSupport::Concern

  included do
    before_action :require_caption_admin!, only: :destroy_caption
  end

  # Atlas deletes the Blob's whole OCFL object, so every earlier revision of
  # that language's caption goes with it and nothing can be rolled back.
  # The id is checked against the Work's own captions, so this cannot be
  # pointed at any other Blob.
  def destroy_caption
    back = edit_work_path(params[:id])
    caption = current_captions.find { |file| file.noid == params[:caption_id] }
    return redirect_to(back, alert: 'This work has no such caption file.') if caption.nil?

    if AtlasRb::Blob.destroy(caption.noid, nuid: current_user.nuid).success?
      redirect_to back, notice: "#{CaptionTrack.label(caption)} caption file removed."
    else
      redirect_to back, alert: 'The caption file could not be removed.'
    end
  end

  private

    def current_captions
      CaptionTrack.all(AtlasRb::Work.assets(params[:id], nuid: viewer_nuid))
    end

    # Admin-only because the Atlas delete is: the edit gate alone would let an
    # editor reach a call Atlas then refuses.
    def require_caption_admin!
      raise CanCan::AccessDenied unless current_user&.admin?
    end

    # State for the Captions section. `files` is absent at deposit, where the Work
    # has no assets yet and so can have no caption to link to.
    def load_caption!(offered:, files: nil)
      @caption_offered = offered
      @captions = CaptionTrack.all(files)
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

      track = caption_track_choice
      return flash[:alert] = CaptionTrack::REFUSED_LANGUAGE if track.nil?

      CaptionJob.perform_later(params[:id], stage_upload(file, params[:id]),
                               file.original_filename, SecureRandom.uuid, track)
    end

    # String keys, because the hash is a job argument.
    def caption_track_choice
      language, label = CaptionTrack.choice(params[:caption_language], other_tag:   params[:caption_language_tag],
                                                                       other_label: params[:caption_language_label])
      { 'language' => language, 'track_label' => label } if language
    end
end
