# frozen_string_literal: true

require 'valkyrie'
require 'shrine/storage/s3'
require 'shrine/storage/file_system'
require 'valkyrie/storage/shrine/checksum/s3'
require 'valkyrie/storage/shrine/checksum/file_system'

Rails.application.config.to_prepare do
  Valkyrie::MetadataAdapter.register(
    Valkyrie::Persistence::Postgres::MetadataAdapter.new,
    :postgres
  )

  Valkyrie::MetadataAdapter.register(
    Valkyrie::Persistence::Memory::MetadataAdapter.new,
    :memory
  )

  Valkyrie::StorageAdapter.register(
    Valkyrie::Storage::Disk.new(
      base_path: Rails.root.join('tmp', 'files'),
      file_mover: FileUtils.method(:cp)
    ),
    :test_disk
  )

  Valkyrie::StorageAdapter.register(
    Valkyrie::Storage::Disk.new(
      base_path: '/home/cerberus/storage/valkyrie',
      file_mover: FileUtils.method(:cp)
    ),
    :disk
  )

  Valkyrie::StorageAdapter.register(
    Valkyrie::Storage::Memory.new,
    :memory
  )

  Valkyrie::MetadataAdapter.register(
    Valkyrie::Persistence::Solr::MetadataAdapter.new(
      connection: Blacklight.default_index.connection,
      resource_indexer: Valkyrie::Persistence::Solr::CompositeIndexer.new(
        Valkyrie::Indexers::AccessControlsIndexer,
        MODSIndexer
      )
    ),
    :index_solr
  )

  Valkyrie::MetadataAdapter.register(
    Valkyrie::AdapterContainer.new(
      persister: Valkyrie::Persistence::CompositePersister.new(
        Valkyrie::MetadataAdapter.find(:postgres).persister,
        Valkyrie::MetadataAdapter.find(:index_solr).persister
      ),
      query_service: Valkyrie::MetadataAdapter.find(:postgres).query_service
    ),
    :composite_persister
  )
end
