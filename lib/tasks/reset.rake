# frozen_string_literal: true

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean, 'db:seed:replant'] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    # Seed as the admin fixture (000000004). :system can't author Works per
    # Atlas's Ability layer (Q7 carve-out only covers Community / Collection);
    # group-gated roles would hit a chicken-and-egg problem with the
    # freshly-created, ungrouped collection. Admin's wildcard authority is
    # the only fixture that carries the whole seed sequence without prior
    # ACL setup. The Current.set block makes atlas_rb's configured
    # default_nuid resolve to the admin NUID for every call inside.
    Current.set(nuid: '000000004') do
      community = AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml')
      river_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/river.jpg')
      AtlasRb::Community.set_thumbnails(community['id'], **ThumbnailCreator.call(base: river_base))
      AtlasRb::Community.metadata(community['id'], { 'permissions' => { 'read' => ['public'] } })

      collection = AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml')
      field_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/field.jpg')
      AtlasRb::Collection.set_thumbnails(collection['id'], **ThumbnailCreator.call(base: field_base))
      AtlasRb::Collection.metadata(collection['id'], { 'permissions' => { 'read' => ['public'] } })

      work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml')
      flower_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/flower.jpg')
      AtlasRb::Work.set_thumbnails(work['id'], **ThumbnailCreator.call(base: flower_base))
      AtlasRb::Work.set_image_derivatives(work['id'], **DerivativeCreator.call(base: flower_base))
      AtlasRb::Work.metadata(work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(work['id'], '/home/cerberus/web/spec/fixtures/files/flower.jpg', 'flower.jpg')
      AtlasRb::Work.complete(work['id'])

      # Marcom loader fixtures — Communications community → Communications
      # Photo Archive collection → Campus Life (Photographs) collection. The
      # middle collection is what the marcom Loader.root_collection points at;
      # the picker in LoadsController#new queries its children (so a future
      # sibling like "Athletics (Photographs)" appears in the dropdown without
      # any code change). Thumbnails reuse the existing JP2 bases — these
      # are dev/staging fixtures, not production imagery.
      communications = AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/communications-mods.xml')
      AtlasRb::Community.set_thumbnails(communications['id'], **ThumbnailCreator.call(base: river_base))
      AtlasRb::Community.metadata(communications['id'], { 'permissions' => { 'read' => ['public'] } })

      photo_archive = AtlasRb::Collection.create(communications['id'], '/home/cerberus/web/spec/fixtures/files/communications-photo-archive-mods.xml')
      AtlasRb::Collection.set_thumbnails(photo_archive['id'], **ThumbnailCreator.call(base: field_base))
      AtlasRb::Collection.metadata(photo_archive['id'], { 'permissions' => { 'read' => ['public'] } })

      campus_life = AtlasRb::Collection.create(photo_archive['id'], '/home/cerberus/web/spec/fixtures/files/campus-life-photographs-mods.xml')
      AtlasRb::Collection.set_thumbnails(campus_life['id'], **ThumbnailCreator.call(base: flower_base))
      AtlasRb::Collection.metadata(campus_life['id'], { 'permissions' => { 'read' => ['public'] } })

      # Cerberus-side: the Loader row binding the marcom Grouper group to the
      # photo-archive root. In prod, an admin creates this through the
      # Admin::LoadersController UI once the equivalent Atlas content exists;
      # dev/staging get it here.
      Loader.find_or_create_by!(slug: 'marcom') do |l|
        l.display_name    = 'Marketing and Communications'
        l.group           = 'northeastern:drs:repository:loaders:marcom'
        l.root_collection = photo_archive['id']
      end
    end
  end

  desc 'Clean Solr and Atlas (AR tables are reset by db:replant)'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    Blacklight.default_index.connection.delete_by_query '*:*'
    Blacklight.default_index.connection.commit
    AtlasRb::Reset.clean
  end
end
