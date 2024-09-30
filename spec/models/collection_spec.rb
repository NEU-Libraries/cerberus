# frozen_string_literal: true

require 'rails_helper'

describe Collection do
  it 'include ActiveModel::API' do
    expect(described_class.included_modules).to include(ActiveModel::API)
  end
end
