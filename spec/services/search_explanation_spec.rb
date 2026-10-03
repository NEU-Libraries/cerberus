# frozen_string_literal: true

require 'rails_helper'

# Read against explanations captured from a real Solr, so the parser is tested
# on the shape edismax actually returns.
RSpec.describe SearchExplanation do
  # Rails.root, not a fixed path: a worktree's specs must read its own fixtures.
  def tree(name) = JSON.parse(Rails.root.join("spec/fixtures/files/#{name}.json").read)

  context 'with one word ("coastal")' do
    subject(:explanation) { described_class.new(tree('explain_one_word')) }

    it 'finds the word and every field it matched in, strongest first' do
      word = explanation.words.sole
      expect(word.term).to eq('coastal')
      expect(word.matches.first.field).to eq('title_tsim')
      expect(word.matches.map(&:label).uniq).to eq(['title', 'description', 'keywords and subjects'])
    end

    it 'says it in a sentence an admin can pass on' do
      expect(explanation.summary)
        .to eq('This appeared because “coastal” is in its title, description, and keywords and subjects fields. ' \
               'The match in its title field counts most.')
    end

    it 'notes the stemmed title and description, so "title" listed twice reads as two matches' do
      notes = explanation.words.sole.matches.to_h { |match| [match.field, match.form_note] }
      expect(notes).to include('title_tsim' => nil, 'title_stem_tesim' => 'stem variation',
                               'description_stem_tesim' => 'stem variation')
      expect(explanation.forms).to eq([:stem_variation])
    end

    it 'reports the score and no adjustment for a Work' do
      expect(explanation.score).to be_within(0.001).of(11.128)
      expect(explanation.adjustments).to eq([])
      expect(explanation.phrases).to eq([])
    end
  end

  context 'with two words ("coastal survey")' do
    subject(:explanation) { described_class.new(tree('explain_two_words')) }

    it 'finds each word, and the phrase bonus apart from them' do
      expect(explanation.words.map(&:term)).to eq(%w[coastal survey])
      expect(explanation.phrases.first.display_term).to eq('coastal survey')
      expect(explanation.phrases.first.label).to eq('title')
    end

    # The phrase bonus outweighed either word alone in the captured tree.
    it 'keeps each word’s clause apart, though a field label holds an “and”' do
      expect(explanation.summary).to start_with(
        'This appeared because “coastal” is in its title, description, and keywords and subjects fields, ' \
        'and “survey” is in its title field.'
      )
    end

    it 'groups the scores by field, strongest field first, so each field shows its text once' do
      title = explanation.fields.first
      expect(title.match.label).to eq('title')
      expect(title.scores.map(&:term)).to include('coastal', 'survey', 'coastal survey')
      expect(explanation.fields.map { |field| field.match.field }).to eq(explanation.fields.map { |f| f.match.field }.uniq)
      expect(explanation.fields.map(&:points)).to eq(explanation.fields.map(&:points).sort.reverse)
    end

    it 'names a field by the label the record gave it, such as the creator for a keyword match' do
      explanation.field_labels = { 'descriptive_keywords_tesim' => 'creator' }

      expect(explanation.summary).to start_with('This appeared because “coastal” is in its title, description, ' \
                                                'and creator fields,')
    end

    it 'speaks the words as typed once it knows them, and keeps Solr’s form otherwise' do
      explanation.typed_terms = { 'survey' => 'Surveys' }

      expect(explanation.summary).to start_with('This appeared because “coastal” is in its title, description, ' \
                                                'and keywords and subjects fields, and “Surveys” is in its title field.')
      expect(explanation.typed('coastal survey')).to eq('coastal Surveys')
    end

    it 'names the phrase as what counted most' do
      expect(explanation.summary).to end_with('The words “coastal survey” also appear together in its title field. ' \
                                              'The words appearing together in its title field count most.')
    end
  end

  context 'with a word both stemmers match ("archive")' do
    subject(:explanation) { described_class.new(tree('explain_word_form')) }

    it 'lists a title row for each stemmer, told apart by its note' do
      notes = explanation.fields.to_h { |field| [field.match.field, [field.match.label, field.match.form_note]] }
      expect(notes).to include('title_stem_tesim'        => ['title', 'stem variation'],
                               'title_kstem_tesim'       => ['title', 'word form'],
                               'description_kstem_tesim' => ['description', 'word form'])
    end

    it 'explains the plural stem before the other word forms in the legend' do
      expect(explanation.forms).to eq(%i[stem_variation word_form])
    end
  end

  # A KStem match is stemmed too, so the word as written names the word.
  it 'takes the word from the exact match, not the KStem one' do
    tree = { 'value' => 2.0, 'description' => 'max plus 0.01 times others of:', 'details' => [
      { 'value' => 2.0, 'description' => 'weight(title_kstem_tesim:archive in 3) [SchemaSimilarity], result of:' },
      { 'value' => 1.0, 'description' => 'weight(title_tsim:archives in 3) [SchemaSimilarity], result of:' }
    ] }

    expect(described_class.new(tree).words.sole.term).to eq('archives')
  end

  # One word matching the title four ways, each with a different note.
  it 'tells the alternative and unformatted titles apart from stem variations, in the legend order' do
    weights = %w[title_plain_tsim title_variant_tesim title_stem_tesim title_tsim].map do |field|
      { 'value' => 1.0, 'description' => "weight(#{field}:whale in 3) [SchemaSimilarity], result of:" }
    end
    explanation = described_class.new({ 'value' => 1.0, 'description' => 'max plus 0.01 times others of:',
                                        'details' => weights })

    expect(explanation.words.sole.matches.map(&:form_note))
      .to contain_exactly('without formatting', 'alternative title', 'stem variation', nil)
    expect(explanation.forms).to eq(%i[stem_variation alternative_title plain_text])
  end

  # One best-field node per word, as edismax builds them.
  def word_node(term, fields)
    weights = fields.map do |field|
      { 'value' => 1.0, 'description' => "weight(#{field}:#{term} in 3) [SchemaSimilarity], result of:" }
    end
    { 'value' => 1.0, 'description' => 'max plus 0.01 times others of:', 'details' => weights }
  end

  it 'gives the words that matched the same fields one clause' do
    tree = { 'value' => 3.0, 'description' => 'sum of:', 'details' => [
      word_node('how', %w[title_tsim description_tsim]), word_node('we', %w[title_tsim]),
      word_node('respond', %w[title_tsim description_tsim])
    ] }

    expect(described_class.new(tree).summary).to start_with(
      'This appeared because “how” and “respond” are in its title and description fields, ' \
      'and “we” is in its title field.'
    )
  end

  # Lucene prints a dropped stop word's kept position as "?".
  it 'notices a phrase with a skipped word in it' do
    phrase = { 'value' => 1.0, 'description' => 'max plus 0.01 times others of:', 'details' => [
      { 'value' => 1.0, 'description' => 'weight(title_tsim:"how we respond ? disaster" in 3) [SchemaSimilarity]' }
    ] }

    expect(described_class.new(phrase).skipped_words?).to be(true)
    expect(described_class.new(tree('explain_two_words')).skipped_words?).to be(false)
  end

  # A quoted search: one phrase node, no per-word nodes, as Solr returns it.
  it 'explains a quoted search by its phrase alone' do
    weights = [['description_tsim:"people ? cities"~1', 7.79], ['description_stem_tesim:"people ? city"~1', 3.9]]
    phrase = { 'value' => 7.83, 'description' => 'max plus 0.01 times others of:',
               'details' => weights.map do |term, value|
                 { 'value' => value, 'description' => "weight(#{term} in 181) [SchemaSimilarity], result of:" }
               end }

    expect(described_class.new(phrase).summary)
      .to eq('This appeared because the words “people ? cities” appear together in its description field.')
  end

  it 'has no sentence when nothing matched by word' do
    expect(described_class.new({ 'value' => 1.0, 'description' => 'MatchAllDocsQuery', 'details' => [] }).summary)
      .to be_nil
  end

  it 'names a score adjustment other than 1, such as the demotion of a Person' do
    person = { 'value' => 0.9, 'description' => 'product of:', 'details' => [
      { 'value' => 0.9, 'description' => 'product of:', 'details' => [
        { 'value' => 1.0, 'description' => 'max plus 0.01 times others of:', 'details' => [
          { 'value' => 1.0, 'description' => 'weight(title_tsim:doe in 3) [SchemaSimilarity], result of:' }
        ] },
        { 'value' => 0.9, 'description' => 'if(exists(query(internal_resource_tesim:person,def=0.0)=0.0),const(0.9),const(1))' }
      ] }
    ] }

    expect(described_class.new(person).adjustments).to eq([0.9])
  end
end
