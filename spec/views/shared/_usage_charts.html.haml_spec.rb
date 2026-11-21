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

  def block(html, title)
    html.css('.usage-chart-block').find { |section| section.at_css('h2').text == title }
  end

  it 'draws one log-axis chart per action that reaches the minimum' do
    chart = block(page, 'Views over time').at_css('.usage-chart')

    expect(chart['data-usage-chart-scale-value']).to eq('log')
    expect(JSON.parse(chart['data-usage-chart-dataset-value']).pluck('name')).to eq(['View'])
  end

  it 'says there are too few to chart below the minimum, and draws nothing' do
    downloads = block(page, 'Downloads over time')

    expect(downloads.at_css('.usage-chart')).to be_nil
    expect(downloads.text).to include('Fewer than 10 downloads in this period, too few to chart.')
  end

  it 'charts the unique visitors from their sum over the period' do
    expect(block(page, 'Unique visitors over time').at_css('.usage-chart')).to be_present
  end

  it 'leaves the unique visitors block out when the page does not want it' do
    expect(block(page(visitors: false), 'Unique visitors over time')).to be_nil
  end
end
