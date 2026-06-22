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
      AtlasRb::Work.metadata(work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(work['id'], '/home/cerberus/web/spec/fixtures/files/flower.jpg', 'flower.jpg')
      AtlasRb::Work.complete(work['id'])

      # Marcom loader fixtures — Communications community → Communications
      # Photo Archive collection → Campus Life (Photographs) collection. The
      # middle collection is what the marcom Loader.root_collection points at;
      # the picker in LoadsController#new queries its children (so a future
      # sibling like "Athletics (Photographs)" appears in the dropdown without
      # any code change). Thumbnails use their own distinct placeholder
      # bases (lake / forest / beach) so the marcom tree doesn't visually
      # duplicate the Northeastern University / Test Collection / What's New
      # seeds in the gallery — these are dev/staging fixtures, not
      # production imagery (lake = public domain, forest = CC0, beach =
      # public domain; all sourced from Wikimedia Commons).
      # Marcom Grouper group seeded onto edit_groups at every level of the
      # community → collection tree so the loader-role test user
      # (NUID 000000003) inherits :update rights on IPTC-deposited Works
      # via Atlas's parent-permission inheritance (WorkCreator copies
      # parent.permissions onto the child). The staff group is auto-
      # prepended by Atlas's permissions= setter; we only add marcom here.
      marcom_group = 'northeastern:drs:repository:loaders:marcom'

      lake_base   = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/lake.jpg')
      forest_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/forest.jpg')
      beach_base  = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/beach.jpg')

      communications = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/communications-mods.xml')
      AtlasRb::Community.set_thumbnails(communications['id'], **ThumbnailCreator.call(base: lake_base))
      AtlasRb::Community.metadata(communications['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [marcom_group] } })

      photo_archive = AtlasRb::Collection.create(communications['id'], '/home/cerberus/web/spec/fixtures/files/communications-photo-archive-mods.xml')
      AtlasRb::Collection.set_thumbnails(photo_archive['id'], **ThumbnailCreator.call(base: forest_base))
      AtlasRb::Collection.metadata(photo_archive['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [marcom_group] } })

      campus_life = AtlasRb::Collection.create(photo_archive['id'], '/home/cerberus/web/spec/fixtures/files/campus-life-photographs-mods.xml')
      AtlasRb::Collection.set_thumbnails(campus_life['id'], **ThumbnailCreator.call(base: beach_base))
      AtlasRb::Collection.metadata(campus_life['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [marcom_group] } })

      # Cerberus-side: the Loader row binding the marcom Grouper group to the
      # photo-archive root. In prod, an admin creates this through the
      # Admin::LoadersController UI once the equivalent Atlas content exists;
      # dev/staging get it here.
      Loader.find_or_create_by!(slug: 'marcom') do |l|
        l.display_name    = 'Marketing and Communications'
        l.group           = marcom_group
        l.root_collection = photo_archive['id']
        l.kind            = :iptc
      end

      # XML loader fixture — the manifest-driven MODS loader (kind: :xml).
      # Points at the photo-archive root so its create-mode destination
      # picker has children (campus_life); update-mode keys off NOIDs in
      # the manifest and ignores the picker. Gated by the loaders:xml
      # Grouper group; dev/staging verification uses admin 000000004,
      # which short-circuits the per-loader group gate.
      Loader.find_or_create_by!(slug: 'xml') do |l|
        l.display_name    = 'XML Metadata Loader'
        l.group           = 'northeastern:drs:repository:loaders:xml'
        l.root_collection = photo_archive['id']
        l.kind            = :xml
      end

      # Curated-content demo (the People/showcase conduit): a Library community
      # under the root, provisioned with its genre showcases, plus a curated
      # Person (Jane Doe) affiliated to it with one work she's published into the
      # Datasets showcase. Gives the deposit fork (publish branch), My DRS,
      # Featured Content, and the Faculty & Staff browse live data to demo.
      library = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/library-mods.xml')
      AtlasRb::Community.set_thumbnails(library['id'], **ThumbnailCreator.call(base: river_base))
      AtlasRb::Community.metadata(library['id'], { 'permissions' => { 'read' => ['public'] } })
      showcases = ShowcaseProvisioner.call(community_id: library['id'])

      # Jane Doe — a curated Person for the staff fixture user (NUID 000000002,
      # seeded by Atlas as "Doe, Jane"). 000000002 is the right subject: it's a
      # seeded, loginable user at the staff/depositor tier (privileged, non-admin),
      # so a demoer can exercise the publish fork as a regular depositor.
      # Person.create mints her personal-root Collection (personal_root_id), the
      # structural home for works she publishes; the affiliation makes the Library
      # her publish target.
      jane = AtlasRb::Person.create(nuid: '000000002', display_name: 'Jane Doe',
                                    title: 'Professor of Marine and Environmental Sciences',
                                    bio: 'Researches coastal resilience and marine ecosystems.')
      AtlasRb::Person.add_affiliation(jane['id'], library['id'])

      # One published work: homed in Jane's personal root, surfaced into the
      # Datasets showcase via the linked-member edge (the conduit). This flips
      # that showcase from hidden-empty to visible in the Library browse and the
      # homepage Featured Content, and populates Jane's My DRS "Published" space.
      datasets = showcases['Datasets']
      if datasets && jane['personal_root_id'].present?
        jane_work = AtlasRb::Work.create(jane['personal_root_id'], depositor: jane['nuid'])
        AtlasRb::Work.set_thumbnails(jane_work['id'], **ThumbnailCreator.call(base: field_base))
        AtlasRb::Work.metadata(jane_work['id'], { 'permissions' => { 'read' => ['public'] } })
        AtlasRb::Blob.create(jane_work['id'], '/home/cerberus/web/spec/fixtures/files/field.jpg', 'coastal-survey.jpg')
        AtlasRb::Work.complete(jane_work['id'])
        AtlasRb::Work.add_linked_member(jane_work['id'], datasets['id'])
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
