# frozen_string_literal: true

# Parses and validates the deposit form's opt-in download sizes
# (`derivative_widths[small|medium|large]`, longest-edge pixels). The
# Stimulus controller is the primary enforcement; this is the server
# backstop, so violations should only occur with JS off or tampered input.
#
# Rules (v1 parity): each size individually optional; each present value a
# whole number within 1..longest_edge (no upscaling); present sizes
# strictly increasing small → medium → large.
class DerivativeWidths < ApplicationService
  ROLES = %i[small medium large].freeze

  Result = Struct.new(:widths, :error, keyword_init: true) do
    def valid?
      error.nil?
    end
  end

  # raw: plain Hash of role => String (already permitted by the controller).
  def initialize(raw:, longest_edge:)
    @raw = raw.to_h.symbolize_keys.slice(*ROLES).transform_values { |v| v.to_s.strip }
               .reject { |_, v| v.empty? }
    @longest_edge = longest_edge
  end

  def call
    return range_error unless @raw.values.all? { |v| whole_number_in_range?(v) }

    values = ROLES.filter_map { |role| @raw[role]&.to_i }
    return ordering_error unless values.each_cons(2).all? { |a, b| a < b }

    Result.new(widths: @raw.transform_values(&:to_i), error: nil)
  end

  private

    def whole_number_in_range?(value)
      value.match?(/\A\d+\z/) && (1..@longest_edge).cover?(value.to_i)
    end

    def range_error
      Result.new(widths: {}, error: 'Each size must be a whole number between 1 and ' \
                                    "#{@longest_edge} pixels (the master image's longest edge).")
    end

    def ordering_error
      Result.new(widths: {}, error: 'Sizes must increase from small to medium to large.')
    end
end
