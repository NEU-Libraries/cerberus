# frozen_string_literal: true

# Whether a Work's staged upload is video, for the deposit metadata page's
# Streaming Only toggle.
#
# The obvious test — does the Work have a video Blob — is not available yet on
# that page: ContentCreationJob may still be in flight when step two renders, so
# asking Atlas would hide the toggle from exactly the deposits that need it. The
# staged file is on disk and settled, so it is the one that can answer.
#
# Shares the deposit staging contract documented on StagedImageProbe:
# WorksController#stage_upload cp's the upload to
# uploads_root/<work_id>/<original_filename>, and ContentCreationJob reads it in
# place rather than consuming it. If that directory is ever reaped this returns
# false and the toggle is simply absent — it must never 500 the deposit.
class StagedVideoProbe < ApplicationService
  def initialize(work_id:)
    @work_id = work_id.to_s
  end

  # @return [Boolean] true when a staged file for this Work is video/*.
  def call
    dir = File.join(Rails.application.config.x.cerberus.uploads_root, @work_id)
    return false unless File.directory?(dir)

    Dir.children(dir).sort.any? do |name|
      path = File.join(dir, name)
      File.file?(path) && Marcel::MimeType.for(Pathname.new(path)).to_s.start_with?('video/')
    end
  rescue SystemCallError
    false
  end
end
