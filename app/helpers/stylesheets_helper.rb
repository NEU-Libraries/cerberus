# frozen_string_literal: true

# The layout's stylesheet tags, in the three shapes a page can take: blocking
# links, inline rules with the full files deferred, or nothing on a Turbo visit.
# See docs/critical-css.md.
module StylesheetsHelper
  BLOCKING = %r{<!-- layout-stylesheets -->.*?<!-- /layout-stylesheets -->}m

  # Applies each deferred stylesheet once it has loaded. A script rather than an
  # onload attribute, so a nonce-based CSP can allow it.
  #
  # A Turbo visit made before they land would render the next page with only
  # this page's inline rules, so the render waits for them. A failed load
  # releases it too, rather than hang the visit.
  APPLY_DEFERRED = <<~JS.squish.freeze
    (function () {
      var links = document.querySelectorAll('link[data-deferred-stylesheet]');
      var waiting = links.length;
      var held = [];
      function settle() {
        if (--waiting === 0) held.splice(0).forEach(function (resume) { resume(); });
      }
      links.forEach(function (link) {
        function apply() { link.media = 'all'; settle(); }
        if (link.sheet) { apply(); return; }
        link.addEventListener('load', apply);
        link.addEventListener('error', settle);
      });
      document.addEventListener('turbo:before-render', function (event) {
        if (waiting === 0) return;
        event.preventDefault();
        held.push(event.detail.resume);
      });
    })();
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

  # The expect link holds the first paint until the layout's last element is
  # parsed. Without it, a page arriving over a slow link paints half-parsed and
  # shifts as later markup lands, such as the sidebar, which sits after the
  # results in the source but displays before them.
  def deferred_stylesheet_tags(critical_css)
    nonce = content_security_policy_nonce
    safe_join([
                tag.link(rel: 'expect', href: '#blacklight-modal', blocking: 'render'),
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
