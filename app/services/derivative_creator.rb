# frozen_string_literal: true

# Builds one rendition URI per role from a gated IIIF base and a set of widths.
# See docs/downloads.md for the width grammar.
class DerivativeCreator < ApplicationService
  # Ratios, so every default is a pure downscale that never trips Cantaloupe's
  # upscale guard. Override per role with `widths:`.
  DEFAULT_WIDTHS = { small: Rational(1, 3), medium: Rational(1, 2), large: Rational(3, 4) }.freeze

  # Match on Atlas's stable `role` token, never the human `use` label.
  ROLES = { 'small_image' => :small, 'medium_image' => :medium, 'large_image' => :large }.freeze

  # The widths that produced a Work's current renditions, recovered from the
  # stored URIs — the only place the depositor's size choice survives. A tier
  # whose size does not parse is LEFT OUT rather than defaulted: defaulting
  # rebuilds Small at full resolution, which is a permission leak.
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

  # Inverse of #iiif_size. :unknown for a token this class does not emit, which
  # the caller must treat as "leave this tier alone".
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
