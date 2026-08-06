# frozen_string_literal: true

class DerivativeCreator < ApplicationService
  # Default size for each role, as a fraction of the source image. Override
  # with `widths:` to pass custom values per role. Each value may be:
  #
  # - Integer       → longest-edge pixels, emitted as IIIF `!N,N` (fit
  #                   within an N×N box, aspect preserved). No `^`, so it
  #                   never upscales — a pure downscale for N ≤ the
  #                   source's longest edge, which the deposit opt-in UI
  #                   guarantees by capping its sliders at that edge.
  # - Numeric ≤ 1   → fraction of source, emitted as IIIF `pct:N` (or
  #                   `^pct:N` for values above 1). A pure downscale
  #                   path that never trips Cantaloupe's upscale guard.
  # - nil           → IIIF `full` (source dimensions, no scaling).
  #
  # Ratio defaults are the sane choice for varying source sizes — they
  # always downscale, never trigger upscaling, and produce derivatives
  # proportionate to whatever the user uploaded.
  DEFAULT_WIDTHS = { small: Rational(1, 3), medium: Rational(1, 2), large: Rational(3, 4) }.freeze

  # Atlas's role token for each rendition, so a Work's current set can be read
  # back out of an assets listing.
  ROLES = { 'small_image' => :small, 'medium_image' => :medium, 'large_image' => :large }.freeze

  # The widths that produced a Work's current renditions — the inverse of #call,
  # recovered from the stored URIs. nil when the Work has none.
  #
  # Replacing a Work's bytes mints a new gated JP2, so every rendition must be
  # rebuilt against the new base at the sizes the Work already carries. Nothing
  # else records those sizes: the depositor chose them once, on the metadata
  # page, and the URIs are the only place that choice survives.
  #
  # The inverse lives beside iiif_size so the grammar of a rendition URI is
  # written down once. A tier whose size does not parse is left out rather than
  # defaulted: defaulting rebuilds Small at full resolution, which is a
  # permission leak rather than a cosmetic error.
  def self.existing_widths(assets)
    widths = {}
    assets.each do |asset|
      role = ROLES[asset['role'].to_s]
      next if role.nil? || asset['uri'].blank?

      width = width_for(asset['uri'])
      if width == :unknown
        Rails.logger.warn("DerivativeCreator: unreadable size in #{asset['uri']} — #{role} not rebuilt")
      else
        widths[role] = width
      end
    end
    widths.presence
  end

  # Inverse of #iiif_size, reading the size segment out of
  # "<base>/full/<size>/0/default.jpg". :unknown for a token this class does not
  # emit, which the caller must treat as "leave this tier alone".
  def self.width_for(uri)
    case uri.split('/')[-3].to_s
    when 'full' then nil
    when /\A!(\d+),\d+\z/ then Regexp.last_match(1).to_i
    when /\A\^?pct:(\d+)\z/ then Rational(Regexp.last_match(1).to_i, 100)
    else :unknown
    end
  end
  private_class_method :width_for

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
      return "!#{width},#{width}" if width.is_a?(Integer)

      pct = (width * 100).round
      pct > 100 ? "^pct:#{pct}" : "pct:#{pct}"
    end
end
