# frozen_string_literal: true

# The layout's stylesheet tags, in the three shapes a page can take: blocking
# links, inline rules with the full files deferred, or nothing on a Turbo visit.
# See docs/critical-css.md.
module StylesheetsHelper
  BLOCKING = %r{<!-- layout-stylesheets -->.*?<!-- /layout-stylesheets -->}m

  # Applies each deferred stylesheet once it has loaded. A script rather than an
  # onload attribute, so a nonce-based CSP can allow it.
  APPLY_DEFERRED = <<~JS.squish.freeze
    document.querySelectorAll('link[data-deferred-stylesheet]').forEach(function (link) {
      function apply() { link.media = 'all'; }
      link.sheet ? apply() : link.addEventListener('load', apply);
    });
  JS

  # Turbo compares tracked <head> elements by their exact HTML. The deferred
  # links change their own media attribute once loaded, so the reload signature
  # lives on this meta tag, which never changes.
  def layout_stylesheet_tags
    signature = tag.meta(name: 'layout-stylesheets', content: layout_stylesheet_paths.join(' '),
                         data: { turbo_track: 'reload' })
    return signature if turbo_request?

    safe_join([signature, "\n", '<!-- layout-stylesheets -->'.html_safe,
               stylesheet_link_tag(*CriticalCss::STYLESHEETS, media: 'all'),
               '<!-- /layout-stylesheets -->'.html_safe])
  end

  def deferred_stylesheet_tags(critical_css)
    nonce = content_security_policy_nonce
    safe_join([
                tag.style(critical_css.gsub('</', '<\/').html_safe, nonce: nonce), # rubocop:disable Rails/OutputSafety -- our own compiled CSS
                stylesheet_link_tag(*CriticalCss::STYLESHEETS, media: 'print', preload_links_header: false,
                                                               data: { deferred_stylesheet: true }),
                javascript_tag(APPLY_DEFERRED, nonce: true),
                tag.noscript(stylesheet_link_tag(*CriticalCss::STYLESHEETS, media: 'all', preload_links_header: false))
              ])
  end

  private

    # Turbo sets this header on every request it makes. A Turbo visit keeps the
    # current <head> stylesheets, so the response sends none: anything it did
    # send would be appended after them and reorder the cascade.
    def turbo_request?
      request.headers['X-Turbo-Request-Id'].present?
    end

    def layout_stylesheet_paths
      CriticalCss::STYLESHEETS.map { |name| asset_path(name, type: :stylesheet) }
    end
end
