# frozen_string_literal: true

require 'rails_helper'
require 'fugit'

# Read from the file rather than through SolidQueue::RecurringTask, whose models
# are unusable under RAILS_ENV=test (see spec/lib/job_queue_inventory_spec.rb).
RSpec.describe 'Recurring task schedule' do
  let(:recurring) do
    YAML.safe_load(Rails.root.join('config/recurring.yml').read, aliases: true)
  end

  # fugit reads a schedule with no zone in the process's system zone, not in
  # config.time_zone, so dropping the suffix would move the run by hours.
  it 'records embargo releases just after midnight Eastern' do
    cron = Fugit.parse_cronish(recurring.dig('production', 'record_embargo_releases', 'schedule'))

    expect(cron.timezone&.name).to eq('America/New_York')
    expect([cron.hours, cron.minutes]).to eq([[0], [15]])
  end

  # The full rollup applies a new bot verdict to every day, and the container
  # rollup sums the leaf counts, so each must follow the one before it.
  it 'reclassifies user agents, then rolls up the full window, then the containers' do
    minute_of_day = lambda do |task|
      cron = Fugit.parse_cronish(recurring.dig('production', task, 'schedule'))
      (cron.hours.first * 60) + cron.minutes.first
    end

    times = %w[reclassify_user_agents rollup_impressions_full rollup_container_impressions].map(&minute_of_day)

    expect(times.each_cons(2)).to all(satisfy { |earlier, later| earlier < later })
  end

  it 'passes the hourly rollup a window the job accepts' do
    args = recurring.dig('production', 'rollup_impressions', 'args')

    expect(args).to eq([{ 'days' => 2 }])
    expect(RollupImpressionsJob.instance_method(:perform).parameters).to include(%i[key days])
  end

  it 'gives staging the same tasks as production' do
    expect(recurring['staging']).to eq(recurring['production'])
  end
end
