# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TusSweepJob do
  it 'sweeps the TUS store' do
    allow(TusStore).to receive(:sweep)

    described_class.perform_now

    expect(TusStore).to have_received(:sweep)
  end

  it 'is scheduled wherever recurring tasks run' do
    tasks = YAML.load_file(Rails.root.join('config/recurring.yml'), aliases: true)

    expect(tasks.dig('production', 'sweep_abandoned_uploads', 'class')).to eq('TusSweepJob')
    expect(tasks.dig('staging', 'sweep_abandoned_uploads', 'class')).to eq('TusSweepJob')
  end
end
