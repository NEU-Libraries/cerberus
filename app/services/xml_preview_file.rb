# frozen_string_literal: true

require 'base64'

# What the XML loader's preview shows of the first manifest row's file: a
# thumbnail when there is one to show, else the file's name, size and type.
# See docs/ingest.md ("The XML preview").
#
# - Create mode, an image or a PDF: a 400 px thumbnail of the row's content
#   file, made once and cached beside the staged archive, then inlined as a
#   data URI, so no route ever serves a staged file.
# - Create mode, anything else: no thumbnail. The size comes from the archive
#   entry's header, so a multi-GB video is never unpacked to be measured.
# - Update mode: the existing Work's current thumbnail, from Atlas.
class XmlPreviewFile < ApplicationService
  THUMBNAIL_PX = 400
  THUMBNAILABLE = %r{\A(image/|application/pdf\z)}

  Result = Struct.new(:name, :byte_size, :mime_type, :thumbnail_src, keyword_init: true)

  def initialize(load_report:, row:)
    @load_report = load_report
    @row = row
  end

  def call
    return if @row.nil?

    @row.update? ? existing_work : content_file
  end

  private

    def existing_work
      work = AtlasRb::Work.find(@row.identifier)
      src = [work&.preview, work&.thumbnail].map(&:to_s).find { |url| url.start_with?('http://', 'https://') }
      Result.new(name: nil, byte_size: nil, mime_type: nil, thumbnail_src: src)
    end

    def content_file
      name = @row.file_name.to_s
      return if name.blank?

      archive = XmlLoader::Archive.new(XmlLoader::Paths.archive_path(@load_report))
      size = archive.size_of(name)
      return if size.nil?

      mime = Marcel::MimeType.for(name: name).to_s
      Result.new(name: name, byte_size: size, mime_type: mime,
                 thumbnail_src: (thumbnail_data_uri(archive, name) if THUMBNAILABLE.match?(mime)))
    end

    # The show page builds the preview on every render, so the thumbnail is made
    # once and read back after. Written to a temp name and renamed, so a second
    # request never reads a half-written file. A failure is cached too, so a
    # corrupt multi-GB file is not re-extracted on every render.
    def thumbnail_data_uri(archive, name)
      cached = File.join(cache_dir, 'thumbnail.jpg')
      failed = File.join(cache_dir, 'no-thumbnail')
      make_thumbnail(archive, name, cached, failed) unless File.exist?(cached) || File.exist?(failed)
      "data:image/jpeg;base64,#{Base64.strict_encode64(File.binread(cached))}" if File.exist?(cached)
    end

    def make_thumbnail(archive, name, cached, failed)
      FileUtils.mkdir_p(cache_dir)
      source = File.join(cache_dir, "source#{File.extname(name)}")
      return unless archive.extract_one(name, source)

      partial = "#{cached}.#{SecureRandom.hex(4)}.jpg"
      Vips::Image.thumbnail(source, THUMBNAIL_PX, height: THUMBNAIL_PX).jpegsave(partial, Q: 82, strip: true)
      File.rename(partial, cached)
    rescue Vips::Error => e
      Rails.logger.warn("XmlPreviewFile: no thumbnail for #{name} (#{e.message.lines.first&.strip})")
      FileUtils.touch(failed)
      nil
    ensure
      FileUtils.rm_f([source, partial].compact)
    end

    def cache_dir
      File.join(XmlLoader::Paths.root(@load_report), 'preview')
    end
end
