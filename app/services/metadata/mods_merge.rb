# frozen_string_literal: true

module Metadata
  # Edits the form-owned fields of a MODS document IN PLACE, preserving every
  # other node, attribute, and namespace (authority-bearing subjects + names,
  # non-Creator names, nested relatedItem titles, genres, extensions,
  # drs:/niec:/xsi: ...). This is the structure-safe counterpart to Atlas's flat
  # plain_title=/plain_description=, which clobber siblings; Cerberus owns the
  # merge, Atlas just stores the XML.
  #
  # Serves both forms: the simple Metadata form (title / abstract / keywords) and
  # the Advanced tab (title parts + personal/corporate creators). Node location,
  # the MODS namespace, node-building, name builders, and whitespace
  # canonicalisation come from the shared NEU::MODS gem; the in-place edit logic
  # (what a form is allowed to change) stays here.
  #
  # A nil field means "leave it untouched"; a value (including "", [], or a
  # creator array) means "set it". Each apply_* skips a write that wouldn't change
  # anything, so a no-op submit doesn't churn nodes or mint an OCFL version.
  class MODSMerge < ApplicationService
    def initialize(xml:, title: nil, abstract: nil, keywords: nil, # rubocop:disable Metrics/ParameterLists
                   subtitle: nil, part_name: nil, part_number: nil, non_sort: nil,
                   personal_creators: nil, corporate_creators: nil)
      @doc = Nokogiri::XML(xml.to_s, &:noblanks)
      @mods = NEU::MODS::Document.new(@doc)
      @title = title
      @abstract = abstract
      @keywords = keywords
      @title_parts = { 'subTitle' => subtitle, 'partName' => part_name,
                       'partNumber' => part_number, 'nonSort' => non_sort }
      @personal_creators = personal_creators
      @corporate_creators = corporate_creators
    end

    def call
      apply_title
      apply_title_parts
      apply_abstract
      apply_keywords
      apply_personal_creators
      apply_corporate_creators
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

        node = @mods.primary_title_info&.at_xpath('mods:title', NEU::MODS::NAMESPACE)
        if node
          node.content = @title unless NEU::MODS.whitespace_equivalent?(node.text, @title)
        elsif @title.present?
          create_primary_title(@title)
        end
      end

      # Structured title parts (subTitle/partName/partNumber/nonSort) on the
      # primary titleInfo. nil = untouched; blank = remove the part; value =
      # edit-in-place or create. (titleInfo's children are an order-independent
      # choice in MODS, so appending a new part is schema-safe.)
      def apply_title_parts
        @title_parts.each { |element, value| apply_title_part(element, value) unless value.nil? }
      end

      def apply_title_part(element, value)
        if value.strip.empty?
          @mods.primary_title_info&.at_xpath("mods:#{element}", NEU::MODS::NAMESPACE)&.remove
          return
        end

        title_info = title_info_for_parts
        node = title_info.at_xpath("mods:#{element}", NEU::MODS::NAMESPACE)
        if node
          node.content = value unless NEU::MODS.whitespace_equivalent?(node.text, value)
        else
          title_info.add_child(@mods.build_node(element, value))
        end
      end

      def apply_abstract
        return if @abstract.nil?

        node = @mods.abstract_nodes.first
        if node
          node.content = @abstract unless NEU::MODS.whitespace_equivalent?(node.text, @abstract)
        elsif @abstract.present?
          @doc.root.add_child(@mods.build_node('abstract', @abstract))
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

      # Replace the set of editable (plain, Creator) personal names with the
      # incoming set, preserving every authority-bearing / non-Creator name.
      def apply_personal_creators
        return if @personal_creators.nil?

        incoming = normalized_personal_creators
        return if incoming == @mods.editable_personal_creators

        @mods.editable_creator_nodes('personal').each(&:remove)
        incoming.each { |c| @doc.root.add_child(@mods.build_personal_name(given: c[:given], family: c[:family])) }
      end

      def apply_corporate_creators
        return if @corporate_creators.nil?

        incoming = normalized_corporate_creators
        return if incoming == @mods.editable_corporate_creators.pluck(:name)

        @mods.editable_creator_nodes('corporate').each(&:remove)
        incoming.each { |name| @doc.root.add_child(@mods.build_corporate_name(name: name)) }
      end

      # --- normalisation (canonical_ws so no-op guards match the gem's read) ----

      def normalized_keywords
        Array(@keywords).map { |k| k.to_s.strip }.reject(&:empty?).uniq
      end

      def normalized_personal_creators
        Array(@personal_creators)
          .map { |c| { given: NEU::MODS.canonical_ws(c[:given]), family: NEU::MODS.canonical_ws(c[:family]) } }
          .reject { |c| c[:given].empty? && c[:family].empty? }
      end

      def normalized_corporate_creators
        Array(@corporate_creators).map { |n| NEU::MODS.canonical_ws(n) }.reject(&:empty?).uniq
      end

      def existing_keywords
        @mods.keyword_subjects.flat_map { |s| s.xpath('mods:topic', NEU::MODS::NAMESPACE).map { |t| t.text.strip } }
      end

      def replace_keyword_subjects(keywords)
        @mods.keyword_subjects.each(&:remove)
        keywords.each do |kw|
          subject = @mods.build_node('subject')
          subject.add_child(@mods.build_node('topic', kw))
          @doc.root.add_child(subject)
        end
      end

      def create_primary_title(title)
        title_info = @mods.build_node('titleInfo')
        title_info['usage'] = 'primary'
        title_info.add_child(@mods.build_node('title', title))
        @doc.root.prepend_child(title_info)
      end

      # Primary titleInfo to hang a part on, creating an (empty) one only if the
      # document has none — callers guard so this never runs for a blank value.
      def title_info_for_parts
        @mods.primary_title_info || begin
          ti = @mods.build_node('titleInfo')
          ti['usage'] = 'primary'
          @doc.root.prepend_child(ti)
          ti
        end
      end

      def normalize_set(arr)
        arr.map { |s| NEU::MODS.canonical_ws(s) }.sort
      end
  end
end
