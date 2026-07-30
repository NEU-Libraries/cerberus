# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsageChartsHelper do
  let(:range) { Date.new(2026, 7, 9)..Date.new(2026, 7, 13) }

  # Views on the 9th and 13th, a download on the 11th only — the shape that
  # broke the chart: each series has days the other doesn't.
  def report
    instance_double(
      ImpressionsReport,
      range:,
      series:                 nil,
      unique_visitors_series: { Date.new(2026, 7, 11) => 2 }
    ).tap do |r|
      allow(r).to receive(:series).with('view')
                                  .and_return(Date.new(2026, 7, 9) => 1, Date.new(2026, 7, 13) => 3)
      allow(r).to receive(:series).with('download').and_return(Date.new(2026, 7, 11) => 5)
    end
  end

  describe '#usage_timeseries' do
    it 'zero-fills every day of the range so both series share identical, chronological keys' do
      view, download = helper.usage_timeseries(report)

      expect(view[:data]).to eq('Jul 9' => 1, 'Jul 10' => 0, 'Jul 11' => 0, 'Jul 12' => 0, 'Jul 13' => 3)
      expect(download[:data]).to eq('Jul 9' => 0, 'Jul 10' => 0, 'Jul 11' => 5, 'Jul 12' => 0, 'Jul 13' => 0)
      expect(download[:data].keys).to eq(view[:data].keys)
    end

    # The bug this guards: a column chart's categorical axis unions each
    # series' own labels in first-seen order, so a download-only day used to
    # land after every view day and the axis stopped being chronological.
    it 'keeps the day labels in calendar order' do
      view = helper.usage_timeseries(report).first

      expect(view[:data].keys).to eq(['Jul 9', 'Jul 10', 'Jul 11', 'Jul 12', 'Jul 13'])
    end

    it 'names each series after its action' do
      expect(helper.usage_timeseries(report).pluck(:name)).to eq(%w[View Download])
    end
  end

  describe '#usage_visitors_series' do
    it 'zero-fills the visitor series across the whole range' do
      series = helper.usage_visitors_series(report).first

      expect(series[:name]).to eq('Unique visitors')
      expect(series[:data]).to eq('Jul 9' => 0, 'Jul 10' => 0, 'Jul 11' => 2, 'Jul 12' => 0, 'Jul 13' => 0)
    end
  end
end
