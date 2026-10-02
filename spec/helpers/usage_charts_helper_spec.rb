# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsageChartsHelper do
  describe '#usage_daily_visitor_average' do
    # Four days, visitors on two: the zero days count, or the average inflates.
    it 'divides by every day in the range, to one decimal' do
      range = Date.new(2026, 9, 1)..Date.new(2026, 9, 4)
      report = instance_double(ImpressionsReport, range:                  range,
                                                  unique_visitors_series: { range.first => 3, range.last => 2 })

      expect(helper.usage_daily_visitor_average(report)).to eq(1.3)
    end
  end

  let(:range) { Date.new(2026, 7, 9)..Date.new(2026, 7, 13) }

  # Views on the 9th and 13th, a download on the 11th and a stream on the 12th —
  # the shape that broke the chart: each series has days the others don't.
  let(:series_by_action) do
    { 'view'     => { Date.new(2026, 7, 9) => 1, Date.new(2026, 7, 13) => 3 },
      'download' => { Date.new(2026, 7, 11) => 5 },
      'stream'   => { Date.new(2026, 7, 12) => 2 } }
  end

  def report
    instance_double(ImpressionsReport, range:, series: nil,
                                       unique_visitors_series: { Date.new(2026, 7, 11) => 2 }).tap do |r|
      allow(r).to receive(:series) { |action| series_by_action.fetch(action) }
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
      expect(helper.usage_timeseries(report).pluck(:name)).to eq(%w[View Download Stream])
    end

    it 'gives each series its own colour, in the same order' do
      expect(helper.usage_series_colors).to eq(%w[#2666a6 #18bc9c #c46410])
    end
  end

  describe '#usage_empty_message' do
    it 'names the range and says when the statistics refresh' do
      expect(helper.usage_empty_message(report))
        .to eq('No activity between July 9, 2026 and July 13, 2026. Usage statistics are refreshed daily.')
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
