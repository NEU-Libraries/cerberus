# frozen_string_literal: true

# The container chain a browser spec needs before it has a page to visit. Atlas
# refuses a resource more visible than its parent, so a public Work needs public
# containers above it, and each tier is widened on the way down.
#
# The environment smoke spec keeps its own copy of this on purpose. It exists to
# fail with its own cause, and sharing a helper would let a break here read as a
# break there.
module AtlasFixtures
  # The repository admin fixture, which every object reset recreates.
  ADMIN_NUID = '000000004'

  def admin_nuid = ADMIN_NUID

  def mods_path(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s

  def read_public = { 'permissions' => { 'read' => ['public'] } }

  def create_community(public: false)
    community = AtlasRb::Community.create(nil, mods_path('community'), nuid: admin_nuid)
    AtlasRb::Community.metadata(community.id, read_public, nuid: admin_nuid) if public
    community
  end

  def create_collection(parent_id, public: false)
    collection = AtlasRb::Collection.create(parent_id, mods_path('collection'), nuid: admin_nuid)
    AtlasRb::Collection.metadata(collection.id, read_public, nuid: admin_nuid) if public
    collection
  end

  # Completed on the way out, because an in-progress Work is still a draft and
  # the edit surfaces do not offer it.
  def create_work(parent_id, public: false)
    work = AtlasRb::Work.create(parent_id, mods_path('work'), nuid: admin_nuid)
    AtlasRb::Work.complete(work.id, nuid: admin_nuid)
    AtlasRb::Work.metadata(work.id, read_public, nuid: admin_nuid) if public
    work
  end
end

RSpec.configure do |config|
  config.include AtlasFixtures, type: :system
end
