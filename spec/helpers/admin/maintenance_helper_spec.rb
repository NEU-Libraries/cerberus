# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::MaintenanceHelper, type: :helper do
  it 'shows an unparseable time as sent rather than failing the page' do
    expect(helper.maintenance_since('soon')).to eq('soon')
  end
end
