# frozen_string_literal: true

# The words in a result's own text that matched the search, field by field, for
# the "Why this result?" dialog. Solr's field analysis runs the record's text
# and the query through the field's own analyzer and flags each record token
# that matches, so a stemmed field bolds "Libraries" for "library". See
# docs/discovery.md ("Why this result?").
class MatchedWords < ApplicationService
  KEYWORD_SOURCES = %w[subject_ssim subject_geo_ssim subject_era_ssim subject_person_ssim subject_corporate_ssim
                       genre_ssim creator_ssim contributor_ssim publisher_ssim place_ssim
                       photo_category_ssim].freeze

  # Searched field → the stored fields its text is copied from (schema.xml's
  # copyFields). The title's plain twin is the title without its markup, which
  # every value loses before analysis anyway.
  SOURCES = {
    'title_tsim'                 => %w[title_tsim],
    'title_stem_tesim'           => %w[title_tsim],
    'title_plain_tsim'           => %w[title_tsim],
    'title_variant_tesim'        => %w[title_variant_tesim],
    'description_tsim'           => %w[description_tsim],
    'description_stem_tesim'     => %w[description_tsim],
    'descriptive_keywords_tesim' => KEYWORD_SOURCES,
    'subject_title_tesim'        => %w[subject_title_tesim],
    'contents_tesim'             => %w[contents_tesim],
    'identifier_tesim'           => %w[identifier_tesim],
    'alternate_ids_tsim'         => %w[alternate_ids_tsim]
  }.freeze

  STORED = SOURCES.values.flatten.uniq.freeze

  # Fields with no text to show: one Solr does not store, one too long to send.
  NO_TEXT = {
    'name_variant_teim' => 'Matched another form of a creator’s name, such as “Tim” for “Timothy”. ' \
                           'Those forms are not stored, so the words cannot be shown.',
    'full_text_tesimv'  => 'Matched in the full text. The result’s full-text snippet shows where.'
  }.freeze

  UNMATCHED = 'Solr matched this field, but the words could not be picked out of its text.'

  # Characters of context either side of the first match in a long value.
  CONTEXT = 60
  MAX_VALUES = 3

  Segment = Struct.new(:text, :matched)

  # One matched value, and the stored field it came from.
  Excerpt = Struct.new(:source, :segments) do
    # The catalog's own facet label for a keyword source ("Creator", "Topic"),
    # so the dialog names a value as the sidebar does. Nil for any other field.
    def source_label
      CatalogController.blacklight_config.facet_fields[source]&.label if KEYWORD_SOURCES.include?(source)
    end
  end

  Line = Struct.new(:match, :excerpts, :reason, :typed, keyword_init: true) do
    # The keywords field gathers eleven stored fields, so "keywords and
    # subjects" hides that the match was, say, the creator. Name the source when
    # every matched value came from one; otherwise each excerpt names its own.
    def label
      sources = excerpts.map(&:source_label).uniq
      sources.one? && sources.first ? sources.first : match.label.capitalize
    end

    def labelled_excerpts? = excerpts.map(&:source_label).compact.uniq.size > 1
  end

  # @param document [SolrDocument] carrying the STORED fields
  # @param matches [Array<SearchExplanation::Match>] one per matched field
  # @param query [String] the words as searched
  def initialize(document:, matches:, query:)
    @document = document
    @matches = matches
    @query = query
    super()
  end

  # @return [Array<Line>] in the order of the matches. Each line's `typed` maps
  #   the field's searched tokens back to the words as typed.
  def call
    @matches.map { |match| line_for(match) }
  end

  private

    def line_for(match)
      pairs = source_values(match.field)
      text = pairs.map(&:last).join("\n")
      analysis = analyse(match.field, text) if pairs.any?
      excerpts = analysis ? per_value(pairs, matched_ranges(analysis, text)).first(MAX_VALUES) : []
      Line.new(match: match, excerpts: excerpts, typed: analysis ? typed_words(analysis) : {},
               reason: (NO_TEXT.fetch(match.field, UNMATCHED) if excerpts.empty?))
    end

    # [source field, plain value] pairs, in SOURCES order.
    def source_values(field)
      pairs = SOURCES.fetch(field, []).flat_map do |source|
        Array(@document[source]).map { |value| [source, value.to_s.gsub(EnhancedTextHelper::TAG_PATTERN, '')] }
      end
      pairs.reject { |pair| pair.last.blank? }
    end

    # One request for every value of the field: joined by newlines, which every
    # analyzer here splits on, so the offsets still find each value.
    def per_value(pairs, ranges)
      offset = 0
      pairs.filter_map do |source, value|
        inside = ranges.filter_map do |range|
          (range.begin - offset)...(range.end - offset) if range.begin >= offset && range.end <= offset + value.length
        end
        offset += value.length + 1
        Excerpt.new(source, excerpt(value, inside)) if inside.any?
      end
    end

    # Solr's offsets count UTF-16 code units, Ruby's string indexes count
    # characters. They differ past any character outside the BMP, such as an
    # emoji, so each offset is converted before it slices the text.
    def matched_ranges(analysis, text)
      utf16 = text.encode('UTF-16LE')
      final_tokens(analysis['index']).select { |token| token['match'] }.map do |token|
        char_index(utf16, token['start'])...char_index(utf16, token['end'])
      end.uniq
    end

    # Every stage keeps a token's position, so the searched form ("survey")
    # traces back to the word as typed ("Surveys") even after stop words drop.
    def typed_words(analysis)
      stages = Array(analysis['query']).grep(Array)
      typed = Array(stages.first).to_h { |token| [token['position'], token['text']] }
      final_tokens(analysis['query']).to_h { |token| [token['text'], typed[token['position']]] }.compact
    end

    # The stages alternate filter name and tokens; the last tokens are the ones searched.
    def final_tokens(stages)
      Array(Array(stages).grep(Array).last)
    end

    # POST, not GET: a long description would overflow Solr's request line.
    # Nil when Solr does not answer, which the line reports instead of failing.
    def analyse(field, text)
      response = Blacklight.default_index.connection.post(
        'analysis/field', data: { 'analysis.fieldname' => field, 'analysis.fieldvalue' => text,
                                  'analysis.query' => @query, 'analysis.showmatch' => true }
      )
      response.dig('analysis', 'field_names', field)
    rescue RSolr::Error::Http, RSolr::Error::ConnectionRefused, Faraday::Error => e
      Rails.logger.warn("MatchedWords: #{e.class} #{e.message}")
      nil
    end

    def char_index(utf16, units)
      utf16.byteslice(0, units * 2).force_encoding('UTF-16LE').length
    end

    def excerpt(value, ranges)
      from = [ranges.first.begin - CONTEXT, 0].max
      to = [ranges.first.end + CONTEXT, value.length].min
      # Widen to whole words, so the ellipsis never cuts one.
      from = (value.rindex(/\s/, from) || -1) + 1 if from.positive?
      to = value.index(/\s/, to) || value.length
      segments(value, ranges.select { |range| range.end <= to }, from, to)
    end

    def segments(value, ranges, from, to)
      out = from.positive? ? [Segment.new('…', false)] : []
      cursor = from
      ranges.each do |range|
        next if range.begin < cursor # an analyzer can emit overlapping tokens

        out << Segment.new(value[cursor...range.begin], false) if range.begin > cursor
        out << Segment.new(value[range], true)
        cursor = range.end
      end
      out << Segment.new(value[cursor...to], false) if to > cursor
      out << Segment.new('…', false) if to < value.length
      out
    end
end
