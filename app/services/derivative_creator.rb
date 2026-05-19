# frozen_string_literal: true

class DerivativeCreator < ApplicationService
  # IIIF image widths (in pixels) for each role. `nil` emits IIIF's `full`
  # size parameter (no resize). Override with `widths:` when a caller has
  # its own notion of small/medium/large.
  DEFAULT_WIDTHS = { small: 800, medium: 1600, large: nil }.freeze

  def initialize(base:, widths: nil)
    @base = base
    @widths = (widths || DEFAULT_WIDTHS).transform_keys(&:to_sym)
  end

  def call
    @widths.each_with_object({}) do |(role, width), hash|
      hash[role.to_s] = "#{@base}/full/#{iiif_size(width)}/0/default.jpg"
    end
  end

  private

    def iiif_size(width)
      width.nil? ? 'full' : "#{width},"
    end
end
