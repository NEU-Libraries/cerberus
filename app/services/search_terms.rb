# frozen_string_literal: true

# The words a reader typed into the catalog search, read the way Solr reads its
# operators, for the "Why this result?" dialog. An excluded word never scores,
# so Solr's explanation is silent about it; this is the only place that knows.
# See docs/discovery.md ("Search operators").
class SearchTerms
  # Uppercase only: lowercase "and", "or" and "not" are words, as in a title.
  OPERATORS = %w[AND OR NOT && ||].freeze

  # A phrase, a group or a bare word, each perhaps negated by NOT or a leading
  # minus. Groups do not nest; an unbalanced bracket falls through as a word
  # boundary, as edismax treats it.
  TERM = /(?<negated>(?<![^\s(])(?:NOT\s+|-))?(?:"(?<phrase>[^"]*)"|\((?<group>[^()]*)\)|(?<word>[^\s()"]+))/

  def initialize(query)
    @query = query.to_s
  end

  # The words that can match, for Solr's field analysis: no operators, nothing
  # excluded, no leading plus.
  def included
    terms.reject { |term| term[:negated] }.flat_map { |term| words_of(term) }.join(' ')
  end

  # Excluded words and phrases, as typed.
  def excluded
    terms.select { |term| term[:negated] }.flat_map { |term| term[:phrase] ? [term[:phrase]] : words_of(term) }
  end

  def only_excludes?
    included.blank? && excluded.any?
  end

  # A sentence for the summary, or nil when nothing was excluded. It opens the
  # summary when there is nothing else to say.
  def exclusion_sentence(opening:)
    return if excluded.empty?

    quoted = excluded.map { |term| "“#{term}”" }.to_sentence(two_words_connector: ' or ', last_word_connector: ', or ')
    sentence = "#{opening ? 'This appeared because it does' : 'It does'} not contain #{quoted}, " \
               'which the search excluded.'
    return sentence unless opening

    "#{sentence} Every result of this search scores the same, so they are listed in browse order."
  end

  private

    def terms
      @terms ||= @query.to_enum(:scan, TERM).map { Regexp.last_match }
    end

    def words_of(term)
      text = term[:phrase] || term[:group] || term[:word]
      text.split.map { |word| word.delete_prefix('+') }.reject { |word| word.empty? || OPERATORS.include?(word) }
    end
end
