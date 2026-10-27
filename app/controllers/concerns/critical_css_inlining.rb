# frozen_string_literal: true

# Rewrites a full page load's blocking layout stylesheets into the page's own
# rules inline, plus the full files deferred. Any failure leaves the blocking
# links in place. See docs/critical-css.md.
module CriticalCssInlining
  extend ActiveSupport::Concern

  included do
    after_action :inline_critical_css
  end

  private

    def inline_critical_css
      # A Live response has already sent its headers and is streaming its body.
      return if response.is_a?(ActionController::Live::Response)
      return unless response.media_type == 'text/html'

      vary_on_turbo
      body = response.body
      return unless body.match?(StylesheetsHelper::BLOCKING)

      css = CriticalCss.for(body)
      response.body = body.sub(StylesheetsHelper::BLOCKING) { helpers.deferred_stylesheet_tags(css) } if css
    rescue StandardError => e
      Rails.logger.warn("[critical_css] kept blocking stylesheets: #{e.class}: #{e.message}")
    end

    # A Turbo visit and a full load of the same URL get different <head>s.
    def vary_on_turbo
      response.headers['Vary'] = [response.headers['Vary'], 'X-Turbo-Request-Id'].compact_blank.join(', ')
    end
end
