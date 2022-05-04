# frozen_string_literal: true

require 'database_cleaner'

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean] do
    include ValkyrieHelper
    include MODSToJson

    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    meta = Valkyrie.config.metadata_adapter
    community = meta.persister.save(resource: Community.new)
    collection = meta.persister.save(resource: Collection.new(a_member_of: community.id))

    file_path = '/home/cerberus/web/test/fixtures/files/work-mods.xml'

    work = WorkCreator.call(parent_id: collection.id)

    # work = meta.persister.save(resource: Work.new(a_member_of: collection.id))

    # # make blob shell
    # fs = meta.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
    # fs.member_ids += [
    #   meta.persister.save(resource: Blob.new(descriptive_metadata_for: work.id)).id
    # ]
    # fs.a_member_of = work.id
    # meta.persister.save(resource: fs)

    # make blob shell
    fs = meta.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
    fs.member_ids += [
      meta.persister.save(resource: Blob.new(descriptive_metadata_for: collection.id)).id
    ]
    fs.a_member_of = collection.id
    meta.persister.save(resource: fs)

    # make blob shell
    fs = meta.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
    fs.member_ids += [
      meta.persister.save(resource: Blob.new(descriptive_metadata_for: community.id)).id
    ]
    fs.a_member_of = community.id
    meta.persister.save(resource: fs)

    work.mods_xml = File.read(file_path)
    collection.mods_xml = File.read('/home/cerberus/web/test/fixtures/files/collection-mods.xml')
    community.mods_xml = File.read('/home/cerberus/web/test/fixtures/files/community-mods.xml')

    work = meta.persister.save(resource: work)

    meta.persister.save(resource: collection)
    meta.persister.save(resource: community)

    # create file set
    fs = Valkyrie.config.metadata_adapter.persister.save(resource: FileSet.new(type: Classification.descriptive_metadata.name))
    fs.member_ids += [
      create_blob(create_file(file_path, fs).id, file_path.split('/').last, Cerberus::Vocab::PCDMUse.MetadataFile, work.id).id
    ]
    fs.a_member_of = work.id
    Valkyrie.config.metadata_adapter.persister.save(resource: fs)
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
