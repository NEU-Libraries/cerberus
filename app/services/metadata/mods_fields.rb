# frozen_string_literal: true

module Metadata
  # Parses the simple-form-owned fields out of a raw MODS document, so the form
  # pre-fills with exactly what MODSMerge will write back — and nothing it would
  # clobber. A thin adapter over the shared NEU::MODS gem: the structured primary
  # title parts (bare title + read-only subtitle/part/non-sort, nil when absent),
  # the BARE first <abstract> (the editable source — NOT the gem's normalised
  # access-copy projection), and the free-text keyword topics (NOT authority-
  # bearing curated subjects).
  class MODSFields < ApplicationService
    def initialize(xml:)
      @mods = NEU::MODS::Document.parse(xml)
    end

    def call
      @mods.title_parts.merge(
        abstract: bare_first_abstract,
        keywords: @mods.keywords
      )
    end

    private

      # The raw first abstract for editing (stripped, nil if empty) — matches the
      # node MODSMerge writes back to, rather than the multi-element paragraph-
      # joined projection used for the access copy.
      def bare_first_abstract
        text = @mods.abstract_nodes.first&.text&.strip
        text.presence
      end
  end
end
