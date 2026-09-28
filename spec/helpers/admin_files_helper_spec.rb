# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminFilesHelper do
  describe '#file_version_when' do
    it 'shows the version time in Eastern, labelled' do
      expect(helper.file_version_when('2026-01-15T03:30:00Z')).to eq('2026-01-14 22:30 EST')
    end

    it 'shows a muted dash for an unparseable time' do
      expect(helper.file_version_when('not a time')).to include('—')
    end
  end
end
