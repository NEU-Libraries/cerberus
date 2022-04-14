require 'database_cleaner'

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    meta = Valkyrie.config.metadata_adapter
  end

  desc 'Clean solr and dbs'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    DatabaseCleaner.strategy = :deletion
    DatabaseCleaner.clean
    Blacklight.default_index.connection.delete_by_query '*:*'
  end

end
