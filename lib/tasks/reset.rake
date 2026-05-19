# frozen_string_literal: true

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean, 'db:seed:replant'] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    community = AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml')
    river_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/river.jpg')
    AtlasRb::Community.set_thumbnails(community['id'], **ThumbnailCreator.call(base: river_base))
    AtlasRb::Community.metadata(community['id'], 'permissions' => { 'read' => ['public'] })

    collection = AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml')
    field_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/field.jpg')
    AtlasRb::Collection.set_thumbnails(collection['id'], **ThumbnailCreator.call(base: field_base))
    AtlasRb::Collection.metadata(collection['id'], 'permissions' => { 'read' => ['public'] })

    work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml')
    flower_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/flower.jpg')
    AtlasRb::Work.set_thumbnails(work['id'], **ThumbnailCreator.call(base: flower_base))
    AtlasRb::Work.set_image_derivatives(work['id'], **DerivativeCreator.call(base: flower_base))
    AtlasRb::Work.metadata(work['id'], 'permissions' => { 'read' => ['public'] })
    AtlasRb::Blob.create(work['id'], '/home/cerberus/web/spec/fixtures/files/flower.jpg', 'flower.jpg')
    AtlasRb::Work.complete(work['id'])
  end

  desc 'Clean Solr and Atlas (AR tables are reset by db:replant)'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    Blacklight.default_index.connection.delete_by_query '*:*'
    Blacklight.default_index.connection.commit
    AtlasRb::Reset.clean
  end
end
