# frozen_string_literal: true

require 'database_cleaner'

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean, 'db:seed'] do
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

  desc 'Clean solr and dbs'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    # database_cleaner-active_record defers requiring its strategy files
    # (Base/Transaction/Truncation/Deletion) until an
    # ActiveSupport.on_load(:active_record) callback fires. In an RSpec
    # setup AR is touched before DC, so the hook has already fired by
    # the time DC is configured — but in a rake task that hasn't yet
    # touched a model, the strategy classes aren't loaded and
    # DC[:active_record].strategy = :deletion raises NameError for
    # DatabaseCleaner::ActiveRecord::Deletion. Require them explicitly
    # to sidestep the load-order timing entirely.
    require 'database_cleaner/active_record/base'
    require 'database_cleaner/active_record/transaction'
    require 'database_cleaner/active_record/truncation'
    require 'database_cleaner/active_record/deletion'

    # Reference the cleaner explicitly so it gets registered. DC 2.x's
    # DatabaseCleaner.strategy= and .clean iterate registered cleaners;
    # if nothing has registered one (rspec auto-registers, rake tasks do
    # not), both calls silently no-op and every reset:data run appends
    # another full seed pass on top of the previous one.
    DatabaseCleaner[:active_record].strategy = :deletion
    DatabaseCleaner.clean
    Blacklight.default_index.connection.delete_by_query '*:*'
    Blacklight.default_index.connection.commit
    AtlasRb::Reset.clean
  end
end
