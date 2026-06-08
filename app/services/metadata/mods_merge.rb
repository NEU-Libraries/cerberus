# frozen_string_literal: true

module Metadata
  # Edits the simple-form-owned fields of a MODS document IN PLACE, preserving
  # every other node, attribute, and namespace (partName/partNumber/nonSort,
  # authority-bearing subjects, name subjects, nested relatedItem titles, names,
  # genres, extensions, drs:/niec:/xsi: ...). This is the structure-safe
  # counterpart to Atlas's flat plain_title=/plain_description=, which clobber
  # siblings; Cerberus owns the merge, Atlas just stores the XML.
  #
  # A nil field means "leave it untouched"; a value (including "" or []) means
  # "set it". Whitespace-equivalent edits are skipped so a form round-trip that
  # only normalises whitespace doesn't mint a needless OCFL version.
  class MODSMerge < ApplicationService
    include MODSHelpers

    def initialize(xml:, title: nil, abstract: nil, keywords: nil)
      @doc = Nokogiri::XML(xml.to_s, &:noblanks)
      @title = title
      @abstract = abstract
      @keywords = keywords
    end

    def call
      apply_title
      apply_abstract
      apply_keywords
      @doc.to_xml
    end

    # True when `merged_xml` is identical (after the same canonicalisation `call`
    # applies) to the original — i.e. the merge was a no-op. The controller uses
    # this to skip the write and avoid minting an unchanged OCFL MODS version.
    def self.unchanged?(original_xml, merged_xml)
      Nokogiri::XML(original_xml.to_s, &:noblanks).to_xml == merged_xml.to_s
    end

    private

      def apply_title
        return if @title.nil?

        node = primary_title_info(@doc)&.at_xpath('mods:title', MODS)
        if node
          node.content = @title unless whitespace_equivalent?(node.text, @title)
        elsif @title.present?
          create_primary_title(@title)
        end
      end

      def apply_abstract
        return if @abstract.nil?

        node = @doc.at_xpath('/mods:mods/mods:abstract', MODS)
        if node
          node.content = @abstract unless whitespace_equivalent?(node.text, @abstract)
        elsif @abstract.present?
          @doc.root.add_child(build_mods_node(@doc, 'abstract', @abstract))
        end
      end

      # Replace the set of free-text keyword subjects with the incoming set,
      # preserving every curated (authority/valueURI) and non-topic subject.
      def apply_keywords
        return if @keywords.nil?

        incoming = normalized_keywords
        return if normalize_set(incoming) == normalize_set(existing_keywords)

        replace_keyword_subjects(incoming)
      end

      def normalized_keywords
        Array(@keywords).map { |k| k.to_s.strip }.reject(&:empty?).uniq
      end

      def existing_keywords
        keyword_subjects(@doc).flat_map { |s| s.xpath('mods:topic', MODS).map { |t| t.text.strip } }
      end

      def replace_keyword_subjects(keywords)
        keyword_subjects(@doc).each(&:remove)
        keywords.each do |kw|
          subject = build_mods_node(@doc, 'subject')
          subject.add_child(build_mods_node(@doc, 'topic', kw))
          @doc.root.add_child(subject)
        end
      end

      def create_primary_title(title)
        title_info = build_mods_node(@doc, 'titleInfo')
        title_info['usage'] = 'primary'
        title_info.add_child(build_mods_node(@doc, 'title', title))
        @doc.root.prepend_child(title_info)
      end

      def normalize_set(arr)
        arr.map { |s| normalize_ws(s) }.sort
      end
  end
end
