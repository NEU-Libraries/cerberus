module Unidecoder
  class << self
    def decode(string)
      string.gsub(/[^x20-x7e]/u) do |character|
        codepoint = character.unpack("U").first
        if should_transliterate?(codepoint)
          CODEPOINTS[code_group(character)][grouped_point(character)] rescue character
        else
          character
        end
      end
    end

    private

    # c.f. http://unicode.org/roadmaps/bmp/
    CODE_POINT_RANGES = {
      :general_punctuation => Set.new(8192 .. 8303),
    }

    def should_transliterate?(codepoint)
      @all_ranges ||= CODE_POINT_RANGES.values.sum
      @all_ranges.include? codepoint
    end
  end
end
