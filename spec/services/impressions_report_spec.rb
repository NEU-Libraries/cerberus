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

  it 'is unscoped without a scope, and show_collections_tab? defaults true' do
    expect(report.scoped?).to be false
    expect(report.show_collections_tab?).to be true
  end

  describe 'when scoped to a single Work (no sub-collections)' do
    let(:scope) do
      instance_double(ImpressionScope, active?: true, overview_noids: ['w1'], top_works_noids: ['w1'],
                                       top_containers_noids: nil, show_collections_tab?: false)
    end

    subject(:scoped_report) { described_class.new(range:, segment: :human, scope:) }

    it 'restricts totals/series to the scope noid set (c1 excluded)' do
      expect(scoped_report.totals).to eq('view' => 10, 'download' => 4)
    end

    it 'restricts top_works ranking to the scope' do
      allow(scoped_report).to receive(:resolve).and_return('w1' => typed_doc('Work'))
      expect(scoped_report.top_works.pluck(:noid)).to eq(['w1'])
    end

    it 'returns no top_containers when the scope hides that tab' do
      expect(scoped_report.top_containers).to eq([])
    end

    it 'computes unique visitors live via ScopedVisitorsQuery instead of the repo-wide rollup' do
      expect(ImpressionDailyVisitor).not_to receive(:series)
      expect(ScopedVisitorsQuery).to receive(:new).with(range:, segment: :human, noids: ['w1'])
                                                  .and_return(instance_double(ScopedVisitorsQuery, series: { Date.current => 2 }))

      expect(scoped_report.unique_visitors_series).to eq(Date.current => 2)
    end

    it 'delegates show_collections_tab? to the scope' do
      expect(scoped_report.show_collections_tab?).to be false
    end
  end

  describe 'when scoped to a container (collections tab applies)' do
    let(:scope) do
      instance_double(ImpressionScope, active?: true, overview_noids: ['c1'], top_works_noids: [],
                                       top_containers_noids: ['c1'], show_collections_tab?: true)
    end

    subject(:scoped_report) { described_class.new(range:, segment: :human, scope:) }

    it 'restricts top_containers ranking to the scope containers' do
      allow(scoped_report).to receive(:resolve).and_return('c1' => typed_doc('Collection'))

      top = scoped_report.top_containers
      expect(top.first[:noid]).to eq('c1')
      expect(top.first[:total]).to eq(120)
    end
  end

  def typed_doc(type)
    doc = instance_double(SolrDocument)
    allow(doc).to receive(:[]).with('internal_resource_tesim').and_return([type])
    doc
  end
end
