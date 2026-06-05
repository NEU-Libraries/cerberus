# frozen_string_literal: true

class Loader < ApplicationRecord
  has_many :load_reports, dependent: :restrict_with_error

  # Which ingest pipeline this loader drives. `iptc` (the default) is the
  # image-archive loader; `xml` is the manifest-driven MODS loader. The
  # value selects the unzip job, the per-row ingest model, and the
  # upload/preview UX in LoadsController and the loads views.
  enum :kind, { iptc: 0, xml: 1 }

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
