# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImpressionsExport do
  let(:report) do
    instance_double(
      ImpressionsReport,
      top_works:      [{ noid: 'w1', doc: nil, counts: { 'view' => 10, 'download' => 4 }, total: 14 }],
      top_containers: [{ noid: 'c1', doc: nil, counts: { 'view' => 120, 'download' => 0 }, total: 120 }]
    )
  end

  it 'renders CSV with a header plus work and container rows' do
    csv = described_class.new(report).csv

    expect(csv).to include('Kind,NOID,Title,View,Download,Total')
    expect(csv).to include('Work,w1,w1,10,4,14')
    expect(csv).to include('Container,c1,c1,120,0,120')
  end

  it 'renders a non-empty xlsx workbook (zip envelope)' do
    xlsx = described_class.new(report).xlsx

    expect(xlsx[0, 2]).to eq('PK') # xlsx is a zip
  end

  # The dashboard's CSV/Excel links sit under one table each, so each must export
  # the table it sits under and nothing else.
  describe 'scoped to one table' do
    it 'exports only the work rows for kind: work' do
      csv = described_class.new(report, kind: 'work').csv

      expect(csv).to include('Work,w1,w1,10,4,14')
      expect(csv).not_to include('Container,c1')
    end

    it 'exports only the container rows for kind: container' do
      csv = described_class.new(report, kind: 'container').csv

      expect(csv).to include('Container,c1,c1,120,0,120')
      expect(csv).not_to include('Work,w1')
    end

    it 'keeps the header on a scoped export' do
      expect(described_class.new(report, kind: 'work').csv)
        .to include('Kind,NOID,Title,View,Download,Total')
    end

    it 'names the scope for the filename, and nothing when it covers both' do
      expect(described_class.new(report, kind: 'work').slug).to eq('files')
      expect(described_class.new(report, kind: 'container').slug).to eq('collections')
      expect(described_class.new(report).slug).to be_nil
    end

    it 'still writes a workbook when scoped' do
      expect(described_class.new(report, kind: 'work').xlsx[0, 2]).to eq('PK')
    end

    # The kind arrives from a URL a curator can edit. A wrong one gives the full
    # export rather than an empty file, so a typo cannot read as "no usage".
    it 'falls back to both tables on an unrecognised kind' do
      csv = described_class.new(report, kind: 'sideways').csv

      expect(csv).to include('Work,w1')
      expect(csv).to include('Container,c1')
    end
  end
end
