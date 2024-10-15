# frozen_string_literal: true

class IptcIngest < ApplicationRecord
  include Ingestible

  validates :image_filename, presence: true
  validates :metadata, presence: true # Raw IPTC parsed metadata

  # def self.create_from_image_binary(...)
  #   TODO: ...
  # end
end
