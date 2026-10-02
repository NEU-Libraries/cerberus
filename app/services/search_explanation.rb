# frozen_string_literal: true

# Reads Solr's structured score explanation (`[explain style=nl]`) for one
# search result into what an admin can repeat to a curious user: which words
# matched in which fields, which match counted most, and any phrase bonus or
# score adjustment. See docs/discovery.md ("Why this result?").
#
# The shape it reads is edismax's: one "max plus 0.01 times others" node per
# query word, holding a weight per field the word matched in, so the best field
# counts and the rest add 1% each; a second such node for the phrase boost
# (`pf`), whose weights carry a quoted phrase; and the boost function
# multiplying the whole. Anything it does not recognise is left out.
class SearchExplanation
  WEIGHT = /\Aweight\((?<field>[a-z_]+):(?<term>"[^"]+"(?:~\d+)?|\S+) in \d+\)/
  BEST_FIELD = 'max plus'

  Word = Struct.new(:term, :matches, :points, keyword_init: true)
  # One searched word's (or the phrase's) share of a field's score.
  Score = Struct.new(:term, :match, keyword_init: true) do
    def phrase? = match.phrase
  end
  # A field the record matched in, with every score it earned there.
  Field = Struct.new(:match, :scores, keyword_init: true) do
    def points = scores.map { |score| score.match.points }.max
  end

  attr_reader :score

  # @param tree [Hash] the `[explain]` value, as { 'value', 'description', 'details' }
  def initialize(tree)
    @tree = tree || {}
    @score = @tree['value'].to_f
  end

  # Per query word, its matches, strongest first.
  def words
    @words ||= best_field_nodes.reject { |node| phrase?(node) }.filter_map { |node| word_from(node) }
  end

  # Matches on the words together, from the phrase boost.
  def phrases
    @phrases ||= best_field_nodes.select { |node| phrase?(node) }.flat_map { |node| matches_in(node) }
                                 .sort_by { |match| -match.points }
  end

  # Multipliers other than 1, such as the slight demotion of Person records.
  def adjustments
    @adjustments ||= collect(@tree) { |node| node['description'].to_s.start_with?('if(') }
                     .map { |node| node['value'].to_f }
                     .reject { |value| (value - 1.0).abs < 1e-6 }
  end

  def strongest
    rows.max_by(&:points)
  end

  # One row per field the record matched in, strongest first. A field holds
  # every word that matched it, and the phrase, so its excerpt shows once.
  def fields
    @fields ||= scores.group_by { |score| score.match.field }
                      .map { |_field, group| Field.new(match: group.first.match, scores: group) }
                      .sort_by { |field| -field.points }
  end

  # The notes the table shows, in the order the legend lists them.
  def forms
    Match::FORM_NOTES.keys & rows.filter_map(&:form)
  end

  # The sentence an admin can pass on. Nil when nothing matched by word, as for
  # a browse with no search terms.
  def summary
    return if words.empty?

    # ", and" between two clauses too: a field label can hold "and" of its own.
    clauses = words.map { |word| word_clause(word) }.to_sentence(two_words_connector: ', and ')
    sentence = "This appeared because #{clauses}."
    [sentence, phrase_sentence, strongest_sentence].compact.join(' ')
  end

  private

    def rows
      words.flat_map(&:matches) + phrases
    end

    def scores
      words.flat_map { |word| word.matches.map { |match| Score.new(term: word.term, match: match) } } +
        phrases.map { |match| Score.new(term: match.display_term, match: match) }
    end

    def best_field_nodes
      collect(@tree) { |node| node['description'].to_s.start_with?(BEST_FIELD) }
    end

    def collect(node, &match)
      found = match.call(node) ? [node] : []
      found + Array(node['details']).flat_map { |child| collect(child, &match) }
    end

    def phrase?(node)
      matches_in(node).any?(&:phrase)
    end

    # Every weight beneath a best-field node, so a field that scored through a
    # nested sum still counts once.
    def matches_in(node)
      collect(node) { |child| child['description'].to_s.match?(WEIGHT) }.filter_map do |weight|
        parts = weight['description'].match(WEIGHT)
        Match.new(field: parts[:field], term: parts[:term], points: weight['value'].to_f,
                  phrase: parts[:term].start_with?('"'))
      end
    end

    def word_from(node)
      matches = matches_in(node).sort_by { |match| -match.points }
      return if matches.empty?

      term = (matches.find { |match| !match.stem_variation? } || matches.first).display_term
      Word.new(term: term, matches: matches, points: node['value'].to_f)
    end

    def word_clause(word)
      "“#{word.term}” is in its #{word.matches.map(&:label).uniq.to_sentence}"
    end

    def phrase_sentence
      phrase = phrases.first
      return if phrase.nil?

      "The words “#{phrase.display_term}” also appear together in its #{phrase.label}."
    end

    def strongest_sentence
      match = strongest
      return if match.nil? || words.sum { |word| word.matches.size } + phrases.size < 2

      if match.phrase
        "The words appearing together in its #{match.label} count most."
      else
        "The #{match.label} match counts most."
      end
    end
end
