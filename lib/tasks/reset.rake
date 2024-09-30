# frozen_string_literal: true

require 'database_cleaner'

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    # community = CommunityCreator.call(mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/community-mods.xml'))
    # collection = CollectionCreator.call(parent_id: community.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/collection-mods.xml'))
    # WorkCreator.call(parent_id: collection.id, mods_xml: File.read('/home/cerberus/web/spec/fixtures/files/work-mods.xml'))

    community = AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml')
    AtlasRb::Community.metadata(community['id'], { 'thumbnail' => ThumbnailCreator.call(path: '/home/cerberus/web/spec/fixtures/files/boat.jpg') })

    collection = AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml')
    AtlasRb::Community.metadata(collection['id'], { 'thumbnail' => ThumbnailCreator.call(path: '/home/cerberus/web/spec/fixtures/files/spongebob.png') })

    work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml')
    AtlasRb::Community.metadata(work['id'], { 'thumbnail' => ThumbnailCreator.call(path: '/home/cerberus/web/spec/fixtures/files/rainbow.jpg') })
  end

  desc 'Clean solr and dbs'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean
    Blacklight.default_index.connection.delete_by_query '*:*'
    Blacklight.default_index.connection.commit
  end
end
