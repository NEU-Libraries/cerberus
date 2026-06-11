# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Metadata::MODSFields do
  let(:xml) { Rails.root.join('spec/fixtures/files/work-mods.xml').read }
  subject(:fields) { described_class.call(xml: xml) }

  it 'extracts the bare primary title, not the composed display title' do
    expect(fields[:title]).to eq("What's New")
  end

  it 'extracts the structured title parts (empty parts come back nil)' do
    expect(fields[:part_name]).to eq('How We Respond to Disaster')
    expect(fields[:part_number]).to eq('Episode 1')
    expect(fields[:non_sort]).to be_nil
    expect(fields[:subtitle]).to be_nil
  end

  it 'extracts the abstract' do
    expect(fields[:abstract]).to include('disasters')
    expect(fields[:abstract]).to include('Stephen')
  end

  it 'returns no keywords when every subject is authority-controlled (curated)' do
    expect(fields[:keywords]).to eq([])
  end

  it 'extracts only free-text keyword topics, not curated subjects' do
    with_kw = Metadata::MODSMerge.call(xml: xml, keywords: %w[alpha beta])
    expect(described_class.call(xml: with_kw)[:keywords]).to contain_exactly('alpha', 'beta')
  end
end
