# frozen_string_literal: true

class Loader < ApplicationRecord
  has_many :load_reports, dependent: :restrict_with_error

  # Which ingest pipeline this loader drives. `iptc` (the default) is the
  # image-archive loader; `xml` is the manifest-driven MODS loader;
  # `multipage` turns one archive (manifest + MODS + ordered page images)
  # into a single Work with positioned page FileSets. The value selects
  # the unzip job, the per-row ingest model, and the upload/preview UX in
  # LoadsController and the loads views.
  enum :kind, { iptc: 0, xml: 1, multipage: 2 }

  validates :slug,
            presence:   true,
            uniqueness: true,
            format:     { with: /\A[a-z0-9_-]+\z/, message: 'must be lowercase letters/digits/dashes/underscores only' }
  validates :display_name, :group, presence: true
  # root_collection is the IPTC safety rail (the deposit picker is boxed to its
  # children). XML and multipage loaders are librarian-operated and pick any
  # destination at upload time, so they need no root collection.
  validates :root_collection, presence: true, if: :iptc?

  default_scope { order(:slug) }

  # The Loaders this user's Grouper groups unlock (admins see the whole
  # registry) — the fine half of the two-tier loader gate. The coarse half
  # is User#loader_tier?; per-request enforcement stays in LoadsController.
  scope :available_to, ->(user) { user&.admin? ? all : where(group: Array(user&.groups)) }

  def to_param
    slug
  end
end
