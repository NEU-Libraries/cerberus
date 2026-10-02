# frozen_string_literal: true

# The media tiers of a Work's staged upload (audio, video, or neither), for the
# deposit metadata page's Streaming Only and Captions sections.
#
# The obvious test — does the Work have an A/V Blob — is not available yet on
# that page: ContentCreationJob may still be in flight when step two renders, so
# asking Atlas would hide the toggle from exactly the deposits that need it. The
# staged file is on disk and settled, so it is the one that can answer.
#
# Shares the deposit staging contract documented on StagedImageProbe:
# WorksController#stage_upload cp's the upload to
# uploads_root/<work_id>/<original_filename>, and ContentCreationJob reads it in
# place rather than consuming it. If that directory is ever reaped this returns
# [] and the sections are simply absent — it must never 500 the deposit.
class StagedMediaProbe < ApplicationService
  def initialize(work_id:)
    @work_id = work_id.to_s
  end

  # @return [Array<String>] StreamingOnly::MEDIA_TIERS present among the staged
  #   files, e.g. ['audio']; empty when none is audio or video.
  def call
    dir = File.join(Rails.application.config.x.cerberus.uploads_root, @work_id)
    return [] unless File.directory?(dir)

    paths = Dir.children(dir).sort.map { |name| File.join(dir, name) }.select { |path| File.file?(path) }
    StreamingOnly.tiers_for_mime_types(paths.map { |path| Marcel::MimeType.for(Pathname.new(path)).to_s })
  rescue SystemCallError
    []
  end
end
