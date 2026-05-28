# frozen_string_literal: true

module Iptc
  # Maps an IPTC tag hash (from Iptc::Extractor) to a MODS XML document.
  # Field-for-field with v1's ImageProcessingJob, minus its mechanics.
  #
  # Required: Headline → mods:title, Keywords (or Subject fallback) →
  # subjects. Missing either raises MissingRequiredField — the caller
  # marks the IptcIngest :failed.
  #
  # Soft issues (byline parse failure, non-Time DateTimeOriginal)
  # collect into Result#warnings for the caller to persist on
  # IptcIngest.warnings; the document still emits, just without the
  # field that couldn't be parsed.
  class ModsBuilder < ApplicationService
    MissingRequiredField = Class.new(StandardError)

    Result = Struct.new(:xml, :warnings, keyword_init: true)

    CATEGORY_LABELS = {
      'ALU' => 'alumni',
      'ATH' => 'athletics',
      'CAM' => 'campus',
      'CLA' => 'classroom',
      'COM' => 'community outreach',
      'EXPERIENTIAL LEARNING' => 'experiential learning',
      'HEA' => 'headshots',
      'POR' => 'portraits',
      'PRE' => 'president',
      'RES' => 'research'
    }.freeze

    MODS_NS = 'http://www.loc.gov/mods/v3'
    XSI_NS  = 'http://www.w3.org/2001/XMLSchema-instance'
    SCHEMA_LOCATION = "#{MODS_NS} http://www.loc.gov/standards/mods/v3/mods-3-5.xsd"

    def initialize(iptc:)
      @iptc = iptc
      @warnings = []
    end

    def call
      validate_required!
      Result.new(xml: build_xml, warnings: @warnings)
    end

    private

      attr_reader :iptc

      def validate_required!
        raise MissingRequiredField, 'Headline' if iptc[:Headline].blank?
        raise MissingRequiredField, 'Keywords' if keywords.empty?
      end

      def keywords
        Array(iptc[:Keywords]).presence || Array(iptc[:Subject])
      end

      def build_xml
        Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
          xml.mods('xmlns'              => MODS_NS,
                   'xmlns:xsi'          => XSI_NS,
                   'xsi:schemaLocation' => SCHEMA_LOCATION) do
            emit_title(xml)
            emit_creators(xml)
            emit_abstract(xml)
            emit_origin_info(xml)
            emit_keyword_subjects(xml)
            emit_geographic_subject(xml)
            emit_classification(xml)
            emit_genre(xml)
            emit_physical_description(xml)
          end
        end.to_xml
      end

      def emit_title(xml)
        xml.titleInfo { xml.title iptc[:Headline] }
      end

      def emit_creators(xml)
        parse_creators.each do |creator|
          xml.name(type: 'personal') do
            xml.namePart(creator[:first], type: 'given')  if creator[:first].present?
            xml.namePart(creator[:last],  type: 'family') if creator[:last].present?
            xml.role do
              xml.roleTerm(iptc[:'By-lineTitle'].presence || 'Creator', type: 'text')
            end
          end
        end
      end

      def parse_creators
        byline = iptc[:'By-line']
        return [] if byline.blank?

        return split_byline(byline, ',') if byline.include?(',')
        return split_byline(byline, ';') if byline.include?(';')

        namae_parse(byline)
      end

      def split_byline(byline, sep)
        last, first = byline.split(sep, 2).map(&:strip)
        [{ first: first, last: last }]
      end

      def namae_parse(byline)
        parsed = Namae.parse(byline).first || Namae.parse(byline.titleize).first
        if parsed && parsed.given.present? && parsed.family.present?
          [{ first: parsed.given, last: parsed.family }]
        else
          @warnings << "By-line could not be parsed. Please format the photographer name as 'Lastname, Firstname'."
          []
        end
      end

      def emit_abstract(xml)
        return if iptc[:Description].blank?

        xml.abstract iptc[:Description]
      end

      def emit_origin_info(xml)
        date = iso_date_created
        source = iptc[:Source]
        return if date.nil? && source.blank?

        xml.originInfo do
          xml.dateCreated(date, keyDate: 'yes', encoding: 'w3cdtf') if date
          xml.publisher(source) if source.present?
        end
      end

      def iso_date_created
        raw = iptc[:DateTimeOriginal]
        return nil if raw.blank?
        return raw.strftime('%F') if raw.is_a?(Time)

        @warnings << "DateTimeOriginal of value #{raw} was not a valid date time string - failed to parse correctly."
        nil
      end

      def emit_keyword_subjects(xml)
        keywords.each do |kw|
          xml.subject { xml.topic kw }
        end
      end

      def emit_geographic_subject(xml)
        return if iptc[:City].blank? && iptc[:State].blank?

        joined = [iptc[:City], iptc[:State]].compact_blank.join(', ')
        xml.subject { xml.geographic joined }
      end

      def emit_classification(xml)
        category = iptc[:Category]
        return if category.blank?

        label  = CATEGORY_LABELS[category.to_s.upcase] || category.to_s.downcase
        suffix = Array(iptc[:SupplementalCategories])
                 .compact_blank
                 .map { |s| " -- #{s.to_s.downcase.tr('_', ' ')}" }
                 .join

        xml.classification "#{label}#{suffix}"
      end

      def emit_genre(xml)
        xml.genre('photographs', authority: 'aat')
      end

      def emit_physical_description(xml)
        xml.physicalDescription do
          xml.form('electronic', authority: 'marcform')
          xml.digitalOrigin('born digital')
          xml.extent('1 photograph')
        end
      end
  end
end
