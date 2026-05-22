# frozen_string_literal: true

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean, 'db:seed:replant'] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    # Seed as the admin fixture (000000004). :system would 403 on Work
    # creation (per Atlas's reject_system_principal); group-gated roles
    # would hit a chicken-and-egg problem with the freshly-created,
    # ungrouped collection. Admin's wildcard authority is the only fixture
    # that carries the whole seed sequence without prior ACL setup.
    Current.set(nuid: '000000004') do
      community = AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', nuid: Current.nuid)
      river_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/river.jpg')
      AtlasRb::Community.set_thumbnails(community['id'], **ThumbnailCreator.call(base: river_base), nuid: Current.nuid)
      AtlasRb::Community.metadata(community['id'], { 'permissions' => { 'read' => ['public'] } }, nuid: Current.nuid)

      collection = AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', nuid: Current.nuid)
      field_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/field.jpg')
      AtlasRb::Collection.set_thumbnails(collection['id'], **ThumbnailCreator.call(base: field_base), nuid: Current.nuid)
      AtlasRb::Collection.metadata(collection['id'], { 'permissions' => { 'read' => ['public'] } }, nuid: Current.nuid)

      work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml', nuid: Current.nuid)
      flower_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/flower.jpg')
      AtlasRb::Work.set_thumbnails(work['id'], **ThumbnailCreator.call(base: flower_base), nuid: Current.nuid)
      AtlasRb::Work.set_image_derivatives(work['id'], **DerivativeCreator.call(base: flower_base), nuid: Current.nuid)
      AtlasRb::Work.metadata(work['id'], { 'permissions' => { 'read' => ['public'] } }, nuid: Current.nuid)
      AtlasRb::Blob.create(work['id'], '/home/cerberus/web/spec/fixtures/files/flower.jpg', 'flower.jpg', nuid: Current.nuid)
      AtlasRb::Work.complete(work['id'], nuid: Current.nuid)
    end
  end

  desc 'Clean Solr and Atlas (AR tables are reset by db:replant)'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    Blacklight.default_index.connection.delete_by_query '*:*'
    Blacklight.default_index.connection.commit
    AtlasRb::Reset.clean
  end
end
