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

  # Searched token → the word as typed, from MatchedWords. Solr's tree holds
  # only the searched form, which for a stemmed match is "survey", not "Surveys".
  attr_writer :typed_terms

  # Field → the label MatchedWords found from the record, such as "creator" for
  # the keywords field, so the summary names the field the table row names.
  attr_writer :field_labels

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

  # A term, or each word of a phrase, as the asker typed it where that is known.
  def label_for(match)
    (@field_labels || {}).fetch(match.field, match.label)
  end

  def typed(term)
    term.split.map { |word| (@typed_terms || {}).fetch(word, word) }.join(' ')
  end

  def strongest
    rows.max_by(&:points)
  end

  # Whether a phrase holds a gap Lucene prints as "?": a stop word the analyzer
  # dropped, whose position the phrase still keeps.
  def skipped_words?
    phrases.any? { |phrase| phrase.display_term.split.include?('?') }
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
  #
  # A quoted search is scored as one phrase, with no per-word nodes at all, so
  # the phrase alone has to carry the sentence then.
  def summary
    return if words.empty? && phrases.empty?
    return phrase_only_sentence if words.empty?

    # ", and" between two clauses too: a field label can hold "and" of its own.
    clauses = word_groups.map { |group| group_clause(group) }.to_sentence(two_words_connector: ', and ')
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

    # Words that matched the same fields share one clause, so a four-word
    # search does not repeat "is in its title and description fields" four times.
    def word_groups
      words.group_by { |word| field_labels_of(word).sort }.values
    end

    def field_labels_of(word)
      word.matches.map { |match| label_for(match) }.uniq
    end

    def group_clause(group)
      labels = field_labels_of(group.first)
      terms = group.map { |word| "“#{typed(word.term)}”" }.to_sentence
      "#{terms} #{group.one? ? 'is' : 'are'} in its #{labels.to_sentence} #{labels.one? ? 'field' : 'fields'}"
    end

    # Phrases come strongest first, so the first names the field that counted most.
    def phrase_only_sentence
      labels = phrases.map { |phrase| label_for(phrase) }.uniq
      "This appeared because the words “#{typed(phrases.first.display_term)}” appear together in its " \
        "#{labels.to_sentence} #{labels.one? ? 'field' : 'fields'}."
    end

    def phrase_sentence
      phrase = phrases.first
      return if phrase.nil?

      "The words “#{typed(phrase.display_term)}” also appear together in its #{label_for(phrase)} field."
    end

    def strongest_sentence
      match = strongest
      return if match.nil? || words.sum { |word| word.matches.size } + phrases.size < 2

      if match.phrase
        "The words appearing together in its #{label_for(match)} field count most."
      else
        "The match in its #{label_for(match)} field counts most."
      end
    end
end
