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
end
