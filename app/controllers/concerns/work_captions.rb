# frozen_string_literal: true

# The Captions section: what the page shows for a Work's captions, and what a
# submitted .vtt does next. The upload is staged and handed to CaptionJob rather
# than written here, because the job has to wait for the primary file to land
# first — both claim the original_file role, and the loser is discarded.
module WorkCaptions
  extend ActiveSupport::Concern

  included do
    before_action :require_caption_steward!, only: %i[remove_caption restore_caption]
    helper_method :caption_steward?
  end

  # Withdraws the caption's FileSet, which takes it out of the player and the
  # downloads while Atlas keeps it, every revision included, for Restore. The
  # id is checked against the Work's own captions, so this cannot be pointed at
  # any other file.
  def remove_caption
    caption = current_captions.find { |file| file.noid == params[:caption_id] }
    return back_to_captions(alert: 'This work has no such caption file.') if caption.nil?

    if AtlasRb::Resource.tombstone(caption.file_set, nuid: current_user.nuid).success?
      back_to_captions(notice: "#{CaptionTrack.label(caption)} caption file removed. It can be restored below.")
    else
      back_to_captions(alert: 'The caption file could not be removed.')
    end
  end

  # A restored caption beside a live one in the same language would give the
  # player two tracks it cannot tell apart, so the live one has to go first.
  def restore_caption
    caption = removed_captions.find { |file| file.file_set == params[:file_set_id] }
    return back_to_captions(alert: 'This work has no such removed caption file.') if caption.nil?

    label = CaptionTrack.label(caption)
    if CaptionTrack.for_language(current_captions, CaptionTrack.language(caption))
      return back_to_captions(alert: "This work already has a #{label} caption file. " \
                                     'Remove it first, then restore this one.')
    end

    if AtlasRb::Admin::Resource.restore(caption.file_set, nuid: current_user.nuid).success?
      back_to_captions(notice: "#{label} caption file restored.")
    else
      back_to_captions(alert: 'The caption file could not be restored.')
    end
  end

  private

    def current_captions
      CaptionTrack.all(AtlasRb::Work.assets(params[:id], nuid: viewer_nuid))
    end

    # Atlas refuses the listing below the delegate tier, so only a steward asks.
    def removed_captions
      CaptionTrack.all(AtlasRb::Work.withdrawn_assets(params[:id], nuid: current_user.nuid))
    end

    # The tiers Atlas allows to withdraw and restore a FileSet. The edit gate
    # alone would let an editor reach a call Atlas then refuses.
    def caption_steward?(user = current_user)
      user.present? && (user.admin? || user.admin_delegate?)
    end

    def require_caption_steward!
      raise CanCan::AccessDenied unless caption_steward?
    end

    def back_to_captions(flash_opts)
      redirect_to edit_work_path(params[:id]), **flash_opts
    end

    # State for the Captions section. `files` is absent at deposit, where the Work
    # has no assets yet and so can have no caption to link to, or remove.
    def load_caption!(offered:, files: nil)
      @caption_offered = offered
      @captions = CaptionTrack.all(files)
      @removed_captions = files && caption_steward?(effective_user) ? removed_captions : []
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
