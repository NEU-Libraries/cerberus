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

  # The form's mandatory-keyword rule stands in for "this record has a subject", so
  # it has to tell a record with NO subjects apart from one whose subjects are all
  # curated and therefore never shown here. Without that, a curator fixing a title
  # on such a record is told it has no keywords and cannot save until they invent
  # one the record does not need.
  describe 'curated_subjects' do
    it 'is true when every subject is authority-controlled, so the box looks empty' do
      expect(fields[:keywords]).to eq([])
      expect(fields[:curated_subjects]).to be true
    end

    it 'stays true once free-text keywords are added alongside the curated ones' do
      with_kw = Metadata::MODSMerge.call(xml: xml, keywords: %w[alpha])
      expect(described_class.call(xml: with_kw)[:curated_subjects]).to be true
    end

    it 'is false when the record carries no subjects at all' do
      bare = <<~XML
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3">
          <mods:titleInfo><mods:title>Bare</mods:title></mods:titleInfo>
        </mods:mods>
      XML
      expect(described_class.call(xml: bare)[:curated_subjects]).to be false
    end

    it 'is false when the only subjects ARE the editable free-text keywords' do
      only_kw = <<~XML
        <mods:mods xmlns:mods="http://www.loc.gov/mods/v3">
          <mods:titleInfo><mods:title>Keywords only</mods:title></mods:titleInfo>
          <mods:subject><mods:topic>free text</mods:topic></mods:subject>
        </mods:mods>
      XML
      parsed = described_class.call(xml: only_kw)
      expect(parsed[:keywords]).to eq(['free text'])
      expect(parsed[:curated_subjects]).to be false
    end
  end
end
