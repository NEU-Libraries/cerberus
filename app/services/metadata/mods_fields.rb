# frozen_string_literal: true

module Metadata
  # Parses the simple-form-owned fields out of a raw MODS document, so the form
  # is pre-filled with exactly what MODSMerge will write back — and nothing it
  # would clobber. Returns the BARE primary title (not Atlas's composed display
  # title), the structured title parts (shown read-only), the first <abstract>,
  # and the free-text keyword topics (NOT authority-bearing curated subjects).
  class MODSFields < ApplicationService
    include MODSHelpers

    def initialize(xml:)
      @doc = Nokogiri::XML(xml.to_s, &:noblanks)
    end

    def call
      ti = primary_title_info(@doc)
      {
        title:       child_text(ti, 'mods:title'),
        subtitle:    child_text(ti, 'mods:subTitle'),
        part_name:   child_text(ti, 'mods:partName'),
        part_number: child_text(ti, 'mods:partNumber'),
        non_sort:    child_text(ti, 'mods:nonSort'),
        abstract:    text_or_nil(@doc.at_xpath('/mods:mods/mods:abstract', MODS)),
        keywords:    keyword_subjects(@doc).flat_map { |s| s.xpath('mods:topic', MODS).map { |t| t.text.strip } }
      }
    end

    private

      def child_text(parent, xpath)
        return nil if parent.nil?

        text_or_nil(parent.at_xpath(xpath, MODS))
      end

      def text_or_nil(node)
        return nil if node.nil?

        txt = node.text.strip
        txt.empty? ? nil : txt
      end
  end
end
