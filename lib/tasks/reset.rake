# frozen_string_literal: true

require 'database_cleaner'

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean] do
    include ValkyrieHelper
    include MODSToJson

    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    meta = Valkyrie.config.metadata_adapter
    community = meta.persister.save(resource: Community.new(title: 'Northeastern University', description: 'Founded in 1898, Northeastern is a global research university and the recognized leader in experience-powered lifelong learning. Our locations-in Boston; the Massachusetts communities of Burlington and Nahant; Charlotte, North Carolina; London; the San Francisco Bay Area; Seattle; Toronto; and Vancouver-are nodes in our global university system. Northeastern\'s comprehensive array of undergraduate and graduate programs lead to degrees through the doctorate in nine colleges and schools.'))
    collection = meta.persister.save(resource: Collection.new(title: 'Test Collection', description: 'Test', a_member_of: community.id))

    file_path = '/home/cerberus/web/test/fixtures/files/mods.xml'
    work = meta.persister.save(resource: Work.new(a_member_of: collection.id))

    mods_json = work.mods
    mods_json.json_attributes = convert_xml_to_json(File.read(file_path))
    mods_json.save!

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
