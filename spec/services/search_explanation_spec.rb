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
        .to eq('This appeared because “coastal” is in its title, description, and keywords and subjects. ' \
               'The title match counts most.')
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
        'This appeared because “coastal” is in its title, description, and keywords and subjects, ' \
        'and “survey” is in its title.'
      )
    end

    it 'names the phrase as what counted most' do
      expect(explanation.summary).to end_with('The words “coastal survey” also appear together in its title. ' \
                                              'The words appearing together in its title count most.')
    end
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
