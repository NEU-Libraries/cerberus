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

  it 'gives staging the same tasks as production' do
    expect(recurring['staging']).to eq(recurring['production'])
  end
end
