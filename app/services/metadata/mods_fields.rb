# frozen_string_literal: true

module Metadata
  # Parses the simple-form-owned fields out of a raw MODS document, so the form
  # pre-fills with exactly what MODSMerge will write back — and nothing it would
  # clobber. A thin adapter over the shared NEU::MODS gem: the structured primary
  # title parts (bare title + read-only subtitle/part/non-sort, nil when absent),
  # the BARE first <abstract> (the editable source — NOT the gem's normalised
  # access-copy projection), and the free-text keyword topics (NOT authority-
  # bearing curated subjects).
  #
  # `curated_subjects` reports whether the document holds topical subjects the
  # form does not surface, so the mandatory-keyword rule can tell "this record has
  # no subjects" apart from "this record's subjects are not editable here".
  class MODSFields < ApplicationService
    def initialize(xml:)
      @mods = NEU::MODS::Document.parse(xml)
    end

    def call
      @mods.title_parts.merge(
        abstract:         bare_first_abstract,
        keywords:         @mods.keywords,
        curated_subjects: curated_subjects?
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

      # Does the document carry topical subjects this form deliberately does not
      # show? `keywords` is only the attribute-free <subject> elements; anything
      # authority-bearing is curated and left alone, so an authority-only record
      # arrives here with subjects on its record page and an empty Keywords box.
      #
      # The form needs to know, because "at least one keyword" is a stand-in for
      # "at least one subject": without this, a record whose subjects are all
      # curated is told it has none and cannot be saved until someone invents a
      # redundant free-text keyword.
      def curated_subjects?
        (@mods.topical_subjects - @mods.keywords).any?
      end
  end
end
