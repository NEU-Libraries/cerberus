# frozen_string_literal: true

module Cerberus
  # The site header, in the slot Blacklight's layout reserves for one.
  #
  # The layout renders `blacklight_config.header_component` and nothing else,
  # so a header that is not reachable from that config key does not appear.
  # Ours is a single partial rather than Blacklight's top-bar/search-bar pair:
  # it carries the impersonation and maintenance banners, the wordmark, and a
  # branded search form, which do not decompose along Blacklight's seam.
  #
  # Rendering the partial from here keeps that markup in a view, where the rest
  # of the app's chrome lives, and leaves this class as the adapter between it
  # and the config key.
  class HeaderComponent < Blacklight::Component
    def initialize(blacklight_config:)
      @blacklight_config = blacklight_config
      super()
    end

    attr_reader :blacklight_config

    def call
      render partial: 'shared/header_navbar'
    end
  end
end
