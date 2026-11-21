# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_usage_charts', type: :view do
  let(:today) { Date.new(2026, 11, 21) }
  let(:totals) { { 'view' => 40, 'download' => 9, 'stream' => 0 } }
  let(:visitors) { { today => 10 } }

  let(:report) do
    instance_double(ImpressionsReport, range: (today - 2)..today, totals: totals,
                                       unique_visitors_series: visitors,
                                       series: { today => 1 })
  end

  def page(visitors: true)
    locals = { report: report, actions: %w[view download stream], period: 'over time', visitors: visitors }
    render partial: 'shared/usage_charts', locals: locals
    Nokogiri::HTML.fragment(rendered)
  end

  def titles(html) = html.css('.usage-chart-block__title').map(&:text)

  it 'draws a log-axis chart for each action that reaches the minimum' do
    chart = page.at_css('.usage-chart-block .usage-chart')

    expect(chart['data-usage-chart-scale-value']).to eq('log')
    expect(JSON.parse(chart['data-usage-chart-dataset-value']).pluck('name')).to eq(['View'])
  end

  it 'leaves out an action below the minimum, heading and all' do
    expect(titles(page)).to eq(['Views over time', 'Unique visitors over time'])
  end

  it 'leaves the unique visitors chart out when the page does not want it' do
    expect(titles(page(visitors: false))).to eq(['Views over time'])
  end

  it 'explains the minimum once, under the charts, with a link to the statistics guide' do
    note = page.at_css('.usage-charts__minimum')

    expect(note.text.squish).to start_with('A graph visualizing interactions with a file will display when a file ' \
                                           'has 10 or more views, downloads, or streams.')
    expect(note.at_css('a')['href']).to eq('https://subjectguides.lib.neu.edu/drs/statistics')
    expect(note.at_css('a').text).to eq('DRS subject guide')
  end
end
