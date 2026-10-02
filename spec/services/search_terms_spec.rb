# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchTerms do
  def terms(query) = described_class.new(query)

  it 'drops operators, exclusions and a leading plus from the words sent for analysis' do
    expect(terms('coastal AND survey').included).to eq('coastal survey')
    expect(terms('(coastal OR disaster) AND resilience').included).to eq('coastal disaster resilience')
    expect(terms('+coastal NOT survey').included).to eq('coastal')
    expect(terms('coastal -survey').included).to eq('coastal')
  end

  # A title typed as written: lowercase operators and hyphens are its own words.
  it 'keeps lowercase operator words and hyphenated words' do
    expect(terms('war and peace').included).to eq('war and peace')
    expect(terms('north-east coast').included).to eq('north-east coast')
    expect(terms('north-east coast').excluded).to eq([])
  end

  it 'reads exclusions by NOT and by minus, keeping a phrase whole' do
    expect(terms('coastal NOT survey -dataset').excluded).to eq(%w[survey dataset])
    expect(terms('coastal NOT "field notes"').excluded).to eq(['field notes'])
    expect(terms('coastal NOT (survey OR dataset)').excluded).to eq(%w[survey dataset])
  end

  it 'knows a search that only excludes' do
    expect(terms('NOT coastal')).to be_only_excludes
    expect(terms('-coastal')).to be_only_excludes
    expect(terms('coastal NOT survey')).not_to be_only_excludes
  end

  it 'says what was excluded, opening the summary when nothing scored' do
    expect(terms('coastal NOT survey -dataset').exclusion_sentence(opening: false))
      .to eq('It does not contain “survey” or “dataset”, which the search excluded.')
    expect(terms('NOT coastal').exclusion_sentence(opening: true))
      .to eq('This appeared because it does not contain “coastal”, which the search excluded. ' \
             'Every result of this search scores the same, so they are listed in browse order.')
    expect(terms('coastal').exclusion_sentence(opening: false)).to be_nil
  end
end
