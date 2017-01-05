module Unidecoder
  class << self
    def decode(string)
      if !string.blank?
        string = string.force_encoding("UTF-8")
        # Required because somehow Marcom was able to place invisible characters into filenames with Photo Mechanic
        # which caused "\xC2" from ASCII-8BIT to UTF-8 (Encoding::UndefinedConversionError)
        string.gsub!(/[\u002D\u00AD\u2010\u2011\u058A\u1806\u2E17\u30FB\uFE63\uFF0D\uFF65\u00B7\u1400\u2027\u2043\u2E1A\u2E31\u2E33\u2E40\u30A0]/,"-")
        # Kludge - en em and figure dash seems to be arbitrarily not being converted. Now doing manually
        string.gsub!("–", "-")
        string.gsub!("—", "-")
        string.gsub!("‒", "-")
        # Kludge - swung dash is also not converted. Manually making tilde
        string.gsub!("⁓", "~")

        string.gsub(/[^x20-x7e]/u) do |character|
          codepoint = character.unpack("U").first
          if should_transliterate?(codepoint)
            CODEPOINTS[code_group(character)][grouped_point(character)] rescue character
          else
            character
          end
        end
      else
        return ""
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
