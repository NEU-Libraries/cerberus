# frozen_string_literal: true

# A named value that changes with the data rather than with a deploy. Deploy
# configuration lives in ENV; a value like the address of the seeded terms Work
# cannot, because the Work gets a new NOID on every reset.
class SiteSetting < ApplicationRecord
  # The keys anything reads. A closed set, so a misspelt key fails validation
  # instead of writing a row that nothing consults.
  KEYS = %w[terms_document_url].freeze

  validates :key, presence: true, uniqueness: true, inclusion: { in: KEYS }

  # @param key [String] one of KEYS
  # @return [String, nil] the stored value, or nil when none is set
  def self.get(key)
    find_by(key: key)&.value.presence
  end

  # @param key [String] one of KEYS
  # @param value [String, nil]
  # @return [SiteSetting]
  def self.set(key, value)
    find_or_initialize_by(key: key).tap { |setting| setting.update!(value: value) }
  end
end
