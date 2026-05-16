# frozen_string_literal: true

require 'rails_helper'

describe ApplicationHelper do
  describe 'application_version' do
    it 'returns the VERSION constant' do
      stub_const('VERSION', '1.0.0')
      expect(helper.application_version).to eq('1.0.0')
    end
  end

end
