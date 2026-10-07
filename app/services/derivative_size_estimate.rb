# frozen_string_literal: true

# Estimates the bytes of an S/M/L rendition before anyone downloads it, for the
# downloads row's "~59 KB". Cantaloupe renders a rendition on request, so no
# size exists to read; this scales the rendition's pixel count by how densely
# its source TIFF compresses. See docs/downloads.md for the calibration. nil
# whenever the source or the size token cannot be read: the row then shows no
# size rather than a wrong one.
class DerivativeSizeEstimate < ApplicationService
  # A pyramid stores about 4/3 of the full-size pixels across its levels.
  PYRAMID_PIXELS = Rational(4, 3)
  # Rendition bytes per pixel, as a fraction of the source TIFF's.
  RATIO = 0.23

  def initialize(uri:)
    @uri = uri.to_s
  end

  def call
    identifier, size = parse
    return if identifier.nil?

    # A source TIFF never changes, so a found estimate is cached for good. A miss
    # is not, so a file that appears later still gets its size.
    Rails.cache.fetch(['derivative-size-estimate', identifier, size], skip_nil: true) { estimate(identifier, size) }
  end

  private

    # .../iiif/3/<identifier>/full/<size>/0/default.jpg
    def parse
      match = %r{/iiif/3/([^/]+)/full/([^/]+)/0/default\.jpg\z}.match(@uri)
      match && [match[1], match[2]]
    end

    def estimate(identifier, size)
      path = File.join(Rails.application.config.x.cerberus.derivatives_root, identifier)
      return unless File.file?(path)

      header = Vips::Image.new_from_file(path)
      scale = scale_for(size, header.width, header.height)
      return if scale.nil?

      source_bpp = File.size(path) / (header.width * header.height * PYRAMID_PIXELS)
      pixels = (header.width * scale).round * (header.height * scale).round
      (pixels * source_bpp * RATIO).round
    rescue Vips::Error
      nil
    end

    # The IIIF size tokens DerivativeCreator emits; anything else is unknown.
    def scale_for(size, width, height)
      case size
      when 'full', 'max' then 1
      when /\A\^?pct:(\d+(?:\.\d+)?)\z/ then Regexp.last_match(1).to_f / 100
      when /\A!(\d+),(\d+)\z/ then [Regexp.last_match(1).to_f / width, Regexp.last_match(2).to_f / height, 1].min
      end
    end
end
