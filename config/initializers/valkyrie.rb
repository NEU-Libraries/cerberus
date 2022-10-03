# frozen_string_literal: true

require 'valkyrie'
require 'shrine/storage/s3'
require 'shrine/storage/file_system'
require 'valkyrie/shrine/checksum/s3'
require 'valkyrie/shrine/checksum/file_system'

Rails.application.config.to_prepare do
  Shrine.storages = {
    s3: Shrine::Storage::S3.new(
      bucket: "drs-access", # required 
      region: "us-east-1", # required 
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key),
    )
  }

  Valkyrie::StorageAdapter.register(
    Valkyrie::Storage::Shrine.new(Shrine.storages[:s3]), :s3
  )

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
