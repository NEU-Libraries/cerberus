# frozen_string_literal: true

# The rules of the layout's stylesheets that one rendered page can use. The
# layout inlines them in <head> and loads the full files without blocking the
# first paint. See docs/critical-css.md.
class CriticalCss
  # Logical names, in the order the layout links them. The inline copy keeps
  # this order, so the cascade is the same before and after the full files land.
  STYLESHEETS = ['application', 'css/all.min'].freeze
  PARSE_LOCK = Mutex.new

  # @param html [String] the complete rendered page
  # @return [String, nil] the CSS to inline, or nil when the stylesheets cannot
  #   be read; the caller then keeps the blocking links.
  def self.for(html)
    rules = current_rules
    rules && new(rules, Markup.tokens(html)).css
  end

  # Parsed once per set of asset digests, so a rebuilt stylesheet in development
  # is picked up on the next request.
  def self.current_rules
    assets = STYLESHEETS.map { |name| Rails.application.assets.load_path.find("#{name}.css") }
    return if assets.any?(&:nil?)

    key = assets.map(&:digest)
    PARSE_LOCK.synchronize do
      @parsed = [key, parse(assets)] unless @parsed&.first == key
      @parsed.last
    end
  end

  def self.parse(assets)
    assets.flat_map { |asset| Stylesheet.parse(asset.compiled_content) }
  end

  def initialize(rules, tokens)
    @rules = rules
    @tokens = tokens
  end

  def css
    styles = @rules.select { |rule| rule.is_a?(Stylesheet::Rule) && needed?(rule) }
    used = styles.map(&:css).join
    keep = Set.new.compare_by_identity.merge(styles)
    wrap(@rules.select { |rule| keep.include?(rule) || keyframes_used?(rule, used) })
  end

  private

    def needed?(rule)
      rule.needs.nil? || rule.needs.any? { |selector| selector.all? { |token| @tokens.include?(token) } }
    end

    def keyframes_used?(rule, text)
      rule.is_a?(Stylesheet::Keyframes) && text.include?(rule.name)
    end

    # Consecutive rules under the same @media (or @supports) chain share one
    # wrapper, so the inline copy does not repeat a query per rule.
    def wrap(rules)
      rules.chunk_while { |a, b| a.context == b.context }.map do |run|
        run.first.context.reverse.reduce(run.map(&:css).join) { |inner, at_rule| "#{at_rule}{#{inner}}" }
      end.join
    end
end
