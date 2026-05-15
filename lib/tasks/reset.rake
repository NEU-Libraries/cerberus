# frozen_string_literal: true

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean, 'db:replant'] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    community = AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml')
    AtlasRb::Community.metadata(community['id'],
                                ThumbnailCreator.call(path: '/home/cerberus/web/spec/fixtures/files/river.jpg')
                                  .merge('permissions' => { 'read' => ['public'] }))

    collection = AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml')
    AtlasRb::Collection.metadata(collection['id'],
                                 ThumbnailCreator.call(path: '/home/cerberus/web/spec/fixtures/files/field.jpg')
                                   .merge('permissions' => { 'read' => ['public'] }))

    work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml')
    AtlasRb::Work.metadata(work['id'],
                           ThumbnailCreator.call(path: '/home/cerberus/web/spec/fixtures/files/flower.jpg')
                             .merge('permissions' => { 'read' => ['public'] }))
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
