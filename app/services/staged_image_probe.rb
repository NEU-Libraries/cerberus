# frozen_string_literal: true

# Dimensions of a Work's staged upload, for the deposit metadata page's
# opt-in Image Derivatives section ("The master image's longest edge is N
# pixels", sliders capped at it).
#
# Depends on the deposit staging contract: WorksController#stage_upload
# cp's the upload to uploads_root/<work_id>/<original_filename> and nothing
# consumes it afterwards (ContentCreationJob reads in place). If a cleanup
# task ever reaps that directory, this probe returns nil and the feature
# degrades gracefully to "section absent" — it must never 500 the page.
class StagedImageProbe < ApplicationService
  Result = Struct.new(:path, :width, :height, keyword_init: true) do
    def longest_edge
      [width, height].max
    end
  end

  def initialize(work_id:)
    @work_id = work_id.to_s
  end

  def call
    path = staged_image_path
    return nil if path.nil?

    # Lazy header read — vips doesn't decode pixels for width/height.
    image = Vips::Image.new_from_file(path)
    Result.new(path: path, width: image.width, height: image.height)
  rescue Vips::Error
    nil # corrupt/unreadable image → no section, never an error page
  end

  private

    def staged_image_path
      dir = File.join(Rails.application.config.x.cerberus.uploads_root, @work_id)
      return nil unless File.directory?(dir)

      Dir.children(dir).sort.filter_map { |name| File.join(dir, name) }
                            .find { |path| File.file?(path) && image?(path) }
    end

    def image?(path)
      Marcel::MimeType.for(Pathname.new(path)).to_s.start_with?('image/')
    end
end
