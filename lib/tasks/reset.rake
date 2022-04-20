# frozen_string_literal: true

require 'database_cleaner'

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    meta = Valkyrie.config.metadata_adapter
    community = meta.persister.save(resource: Community.new(title: 'Northeastern University', description: 'Founded in 1898, Northeastern is a global research university and the recognized leader in experience-powered lifelong learning. Our locations-in Boston; the Massachusetts communities of Burlington and Nahant; Charlotte, North Carolina; London; the San Francisco Bay Area; Seattle; Toronto; and Vancouver-are nodes in our global university system. Northeastern\'s comprehensive array of undergraduate and graduate programs lead to degrees through the doctorate in nine colleges and schools.'))
    collection = meta.persister.save(resource: Collection.new(title: 'Test Collection', description: 'Test', a_member_of: community.id))
    meta.persister.save(resource: Work.new(a_member_of: collection.id))
  end

  desc 'Clean solr and dbs'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean
    Blacklight.default_index.connection.delete_by_query '*:*'
  end
end
