# frozen_string_literal: true

class Loader < ApplicationRecord
  has_many :load_reports, dependent: :restrict_with_error

  validates :slug,
            presence:   true,
            uniqueness: true,
            format:     { with: /\A[a-z0-9_-]+\z/, message: 'must be lowercase letters/digits/dashes/underscores only' }
  validates :display_name, :group, :root_collection, presence: true

  default_scope { order(:slug) }

  def to_param
    slug
  end
end
