# frozen_string_literal: true

require 'rails_helper'

# Against the live test Solr: the analysis response and its offsets are the
# contract under test, and a stub would only restate this file's assumptions.
RSpec.describe MatchedWords do
  def field_match(field) = SearchExplanation::Match.new(field: field, term: 'x', points: 1.0, phrase: false)

  def lines(document, fields, query)
    described_class.call(document: SolrDocument.new(document), matches: fields.map { |f| field_match(f) }, query: query)
  end

  def rendered(line) = line.excerpts.map { |e| e.segments.map { |s| s.matched ? "[#{s.text}]" : s.text }.join }

  it 'bolds the word as the record writes it, for a stemmed match' do
    line = lines({ 'title_tsim' => ['Libraries of the Northeast'] }, %w[title_stem_tesim], 'library').sole

    expect(rendered(line)).to eq(['[Libraries] of the Northeast'])
    expect(line.reason).to be_nil
  end

  it 'leaves an inflected word unbolded in the field that matches only as written' do
    line = lines({ 'title_tsim' => ['Libraries of the Northeast'] }, %w[title_tsim], 'northeast libraries').sole

    expect(rendered(line)).to eq(['[Libraries] of the [Northeast]'])
  end

  it 'finds the words past an emoji, whose UTF-16 width shifts Solr’s offsets' do
    line = lines({ 'title_tsim' => ['🌊 Coastal survey'] }, %w[title_tsim], 'survey').sole

    expect(rendered(line)).to eq(['🌊 Coastal [survey]'])
  end

  it 'drops the title markup before it is analysed' do
    line = lines({ 'title_tsim' => ['Bi<sub>2</sub> films'] }, %w[title_tsim], 'films').sole

    expect(rendered(line)).to eq(['Bi2 [films]'])
  end

  it 'shows only the keyword values that matched, from every source field' do
    document = { 'subject_ssim' => ['Whales', 'Ocean currents'], 'place_ssim' => ['Boston Harbor'] }
    line = lines(document, %w[descriptive_keywords_tesim], 'harbor').sole

    expect(rendered(line)).to eq(['Boston [Harbor]'])
  end

  # The keywords field gathers eleven stored fields, so its own label would
  # call a creator match a keyword.
  it 'names a keyword match by its one source, as the facet sidebar does' do
    line = lines({ 'creator_ssim' => ['Lovelace, Ada'], 'subject_ssim' => ['Computing'] },
                 %w[descriptive_keywords_tesim], 'ada').sole

    expect(rendered(line)).to eq(['Lovelace, [Ada]'])
    expect(line.label).to eq('Creator')
    expect(line.labelled_excerpts?).to be(false)
  end

  it 'names each value when the keyword matches came from more than one source' do
    line = lines({ 'creator_ssim' => ['Lovelace, Ada'], 'subject_ssim' => ['Ada (Computer program language)'] },
                 %w[descriptive_keywords_tesim], 'ada').sole

    expect(line.label).to eq('Keywords and subjects')
    expect(line.labelled_excerpts?).to be(true)
    expect(line.excerpts.map(&:source_label)).to eq(%w[Topic Creator])
  end

  it 'keeps the field’s own label outside the keywords field' do
    line = lines({ 'title_tsim' => ['Coastal survey'] }, %w[title_tsim], 'survey').sole

    expect(line.label).to eq('Title')
  end

  it 'trims a long value to the match, and says so' do
    description = "#{'Before. ' * 20}The harbor survey began. #{'After. ' * 20}"
    excerpt = rendered(lines({ 'description_tsim' => [description] }, %w[description_tsim], 'harbor').sole).sole

    expect(excerpt).to start_with('…').and end_with('…').and include('[harbor]')
    expect(excerpt).to match(/\A…Before\./).and match(/After\.…\z/)
  end

  # Positions survive every stage, so the stem traces back past the stop words.
  it 'maps each searched form back to the word as typed' do
    line = lines({ 'title_tsim' => ['Coastal surveys'] }, %w[title_stem_tesim], 'Coastal Surveys of the libraries').sole

    expect(line.typed).to eq('coastal' => 'Coastal', 'survey' => 'Surveys', 'library' => 'libraries')
  end

  it 'explains a field it has no text for' do
    line = lines({}, %w[full_text_tesimv], 'harbor').sole

    expect(line.excerpts).to eq([])
    expect(line.reason).to eq(MatchedWords::NO_TEXT['full_text_tesimv'])
  end

  it 'gives the fallback reason rather than failing when Solr does not answer' do
    allow(Blacklight.default_index.connection).to receive(:post).and_raise(Faraday::ConnectionFailed, 'down')

    line = lines({ 'title_tsim' => ['Coastal survey'] }, %w[title_tsim], 'survey').sole

    expect(line.excerpts).to eq([])
    expect(line.reason).to eq(MatchedWords::UNMATCHED)
    expect(line.typed).to eq({})
  end
end
