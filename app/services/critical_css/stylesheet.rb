# frozen_string_literal: true

class CriticalCss
  # One compiled stylesheet split into its top-level rules, each tagged with the
  # tokens a page must carry for the rule to apply. See docs/critical-css.md.
  class Stylesheet
    # `needs` is one token list per selector in the rule's selector list, or nil
    # for a rule every page keeps (@font-face, @property and the like).
    Rule = Data.define(:css, :context, :needs)
    Keyframes = Data.define(:css, :context, :name)

    GROUPING = /\A@(media|supports|container|layer|document)\b/
    KEYFRAMES = /\A@(?:-webkit-)?keyframes\s+(\S+)/
    SPECIAL = %r{[{};"'/]}
    BOM = "\uFEFF"

    def self.parse(text)
      new(text.dup.force_encoding(Encoding::UTF_8).delete_prefix(BOM)).rules
    end

    # Scanned as bytes: indexing a multibyte UTF-8 string by character offset is
    # linear per call, which makes the scan quadratic. Every cut falls on an
    # ASCII delimiter, so each slice is valid UTF-8 again.
    def initialize(text)
      @text = text.b
    end

    def rules
      @rules ||= scan
    end

    private

      def scan
        @out = []
        @context = []
        advance(0)
        step while (@pos = @text.index(SPECIAL, @pos))
        @out
      end

      def step
        case @text[@pos]
        when '/' then @pos = skip_comment(@pos)
        when '"', "'" then @pos = skip_string(@pos)
        when ';' then advance
        when '}' then close_group
        when '{' then open_block
        end
      end

      def advance(to = @pos + 1)
        @pos = @prelude_start = to
      end

      def close_group
        @context.pop
        advance
      end

      # A grouping rule (@media and the like) opens a context its children carry;
      # anything else is one rule, taken whole up to its matching brace.
      def open_block
        prelude = utf8(strip_comments(@text[@prelude_start...@pos]).strip)
        if prelude.match?(GROUPING)
          @context.push(prelude)
          return advance
        end

        block_end = matching_brace(@pos)
        @out << rule(prelude, utf8(@text[@pos..block_end]), @context.dup)
        advance(block_end + 1)
      end

      def rule(prelude, block, context)
        css = prelude + block
        if (name = prelude[KEYFRAMES, 1])
          Keyframes.new(css:, context:, name:)
        elsif prelude.start_with?('@')
          Rule.new(css:, context:, needs: nil)
        else
          Rule.new(css:, context:, needs: Selector.needs(prelude))
        end
      end

      def matching_brace(open)
        depth = 0
        pos = open
        while (pos = @text.index(SPECIAL, pos))
          case @text[pos]
          when '/' then next pos = skip_comment(pos)
          when '"', "'" then next pos = skip_string(pos)
          when '{' then depth += 1
          when '}' then depth -= 1
                        return pos if depth.zero?
          end
          pos += 1
        end
        @text.length - 1
      end

      # A lone '/' (as in `font: 1rem/1.5`) is not a comment and is stepped over.
      def skip_comment(pos)
        return pos + 1 unless @text[pos + 1] == '*'

        (@text.index('*/', pos + 2) || @text.length) + 2
      end

      def skip_string(pos)
        quote = @text[pos]
        pos += 1
        pos += @text[pos] == '\\' ? 2 : 1 while pos < @text.length && @text[pos] != quote
        pos + 1
      end

      def strip_comments(prelude)
        prelude.gsub(%r{/\*.*?\*/}m, '')
      end

      def utf8(bytes)
        bytes.force_encoding(Encoding::UTF_8)
      end
  end
end
