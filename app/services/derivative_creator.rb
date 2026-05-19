# frozen_string_literal: true

class DerivativeCreator < ApplicationService
  # Default size for each role, as a fraction of the source image. Override
  # with `widths:` to pass custom values per role. Each value may be:
  #
  # - Integer       → fixed pixel width, emitted as IIIF `^N,` so a
  #                   request that exceeds the source's width is at
  #                   least syntactically tolerated (Cantaloupe may still
  #                   reject if its `processor.upscale_filter` config
  #                   disallows upscaling, in which case the caller is
  #                   over-asking for that source).
  # - Numeric ≤ 1   → fraction of source, emitted as IIIF `pct:N` (or
  #                   `^pct:N` for values above 1). A pure downscale
  #                   path that never trips Cantaloupe's upscale guard.
  # - nil           → IIIF `full` (source dimensions, no scaling).
  #
  # Ratio defaults are the sane choice for varying source sizes — they
  # always downscale, never trigger upscaling, and produce derivatives
  # proportionate to whatever the user uploaded.
  DEFAULT_WIDTHS = { small: Rational(1, 3), medium: Rational(1, 2), large: Rational(3, 4) }.freeze

  def initialize(base:, widths: nil)
    @base = base
    @widths = (widths || DEFAULT_WIDTHS).transform_keys(&:to_sym)
  end

  def call
    @widths.each_with_object({}) do |(role, width), hash|
      hash[role] = "#{@base}/full/#{iiif_size(width)}/0/default.jpg"
    end
  end

  private

    def iiif_size(width)
      return 'full' if width.nil?
      return "^#{width}," if width.is_a?(Integer)

      pct = (width * 100).round
      pct > 100 ? "^pct:#{pct}" : "pct:#{pct}"
    end
end
