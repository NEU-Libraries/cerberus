# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImpressionsReport do
  let(:range) { (Date.current - 7)..Date.current }

  subject(:report) { described_class.new(range:, segment: :human) }

  before do
    ImpressionDailyCount.create!(noid: 'w1', action: 'view',     day: Date.current, count: 10)
    ImpressionDailyCount.create!(noid: 'w1', action: 'download', day: Date.current, count: 4)
    ImpressionDailyCount.create!(noid: 'c1', action: 'view',     day: Date.current, count: 99)
    ImpressionDailyVisitor.create!(day: Date.current, unique_visitors: 7)
    ImpressionContainerDailyCount.create!(noid: 'c1', action: 'view', day: Date.current, count: 120)
  end

  it 'totals each action across all noids in the range' do
    expect(report.totals).to eq('view' => 109, 'download' => 4)
  end

  it 'returns a day => count series for an action' do
    expect(report.series('view')).to eq(Date.current => 109)
  end

  it 'returns the unique-visitors series' do
    expect(report.unique_visitors_series).to eq(Date.current => 7)
  end

  it 'top_works keeps only Work-typed leaf noids with per-action counts' do
    allow(report).to receive(:resolve).and_return(
      'w1' => typed_doc('Work'), 'c1' => typed_doc('Collection')
    )

    works = report.top_works
    expect(works.pluck(:noid)).to eq(['w1'])
    expect(works.first[:counts]).to eq('view' => 10, 'download' => 4)
    expect(works.first[:total]).to eq(14)
  end

  it 'top_containers reads the container rollup' do
    allow(report).to receive(:resolve).and_return('c1' => typed_doc('Collection'))

    top = report.top_containers
    expect(top.first[:noid]).to eq('c1')
    expect(top.first[:total]).to eq(120)
  end

  it 'the :all segment reads the continuous aggregate, not the human rollup' do
    all_report = described_class.new(range:, segment: :all)
    expect(all_report.segment).to eq(:all)
    expect(ImpressionCountByDay).to receive(:for_action).with('view').and_return(ImpressionCountByDay.none)
    all_report.series('view')
  end

  def typed_doc(type)
    doc = instance_double(SolrDocument)
    allow(doc).to receive(:[]).with('internal_resource_tesim').and_return([type])
    doc
  end
end
