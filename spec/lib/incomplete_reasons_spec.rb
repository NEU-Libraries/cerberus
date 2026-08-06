# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IncompleteReasons do
  it 'describes each token in terms of what the reader lost' do
    expect(described_class.describe(described_class::PDF_RENDITION)).to eq(
      'No PDF version was made, so this document has no preview.'
    )
  end

  # The fallback is what lets a job introduce a token without a view change, and
  # is why an unknown one can never blank a page.
  it 'falls back to a generic sentence for a token it has not been taught' do
    expect(described_class.describe('some_new_job_gave_up')).to eq(described_class::UNKNOWN)
  end

  it 'falls back for a nil reason' do
    expect(described_class.describe(nil)).to eq(described_class::UNKNOWN)
  end

  # Atlas stores the token opaquely, so this map is its only definition — a token
  # set by a job with no entry here would read as the generic fallback forever.
  it 'has a description for every token it defines' do
    tokens = described_class.constants.filter_map do |name|
      value = described_class.const_get(name)
      value if value.is_a?(String) && name != :UNKNOWN
    end

    expect(tokens).to all(satisfy { |token| described_class::DESCRIPTIONS.key?(token) })
  end
end
