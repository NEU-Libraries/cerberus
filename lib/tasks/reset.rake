# frozen_string_literal: true

namespace :reset do
  desc 'Clean database and repopulate with sample data'
  task data: [:clean, 'db:seed:replant'] do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    # Institutional containers belong to nobody in particular — see
    # Permissions::UNOWNED_NUID for the reasoning, and ShowcaseProvisioner for
    # the other caller. Authorization is a separate axis: the task still ACTS as
    # the admin fixture (see the Current.set below); this only records who owns
    # it. Read inside the task body, not at namespace level: rake files are
    # loaded before app constants are autoloadable, so a top-level reference
    # raises NameError before any task can run.
    unowned = Permissions::UNOWNED_NUID

    # Seed as the admin fixture (000000004). :system can't author Works —
    # Atlas's Ability only lets it create Communities / Collections;
    # group-gated roles would hit a chicken-and-egg problem with the
    # freshly-created, ungrouped collection. Admin's wildcard authority is
    # the only fixture that carries the whole seed sequence without prior
    # ACL setup. The Current.set block makes atlas_rb's configured
    # default_nuid resolve to the admin NUID for every call inside.
    Current.set(nuid: '000000004') do
      community = AtlasRb::Community.create(nil, '/home/cerberus/web/spec/fixtures/files/community-mods.xml', depositor: unowned)
      river_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/river.jpg').open_base
      AtlasRb::Community.set_thumbnails(community['id'], **ThumbnailCreator.call(base: river_base))
      AtlasRb::Community.metadata(community['id'], { 'permissions' => { 'read' => ['public'] } })

      collection = AtlasRb::Collection.create(community['id'], '/home/cerberus/web/spec/fixtures/files/collection-mods.xml', depositor: unowned)
      field_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/field.jpg').open_base
      AtlasRb::Collection.set_thumbnails(collection['id'], **ThumbnailCreator.call(base: field_base))
      AtlasRb::Collection.metadata(collection['id'], { 'permissions' => { 'read' => ['public'] } })

      work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-mods.xml')
      flower_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/flower.jpg').open_base
      AtlasRb::Work.set_thumbnails(work['id'], **ThumbnailCreator.call(base: flower_base))
      AtlasRb::Work.metadata(work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(work['id'], '/home/cerberus/web/spec/fixtures/files/flower.jpg', 'flower.jpg')
      AtlasRb::Work.complete(work['id'])

      # Audio/video sample so a reset demonstrates the in-browser video.js
      # player and the seekable Range media endpoint on real seed data. The
      # clip is already H.264/AAC MP4 (the safe codec set), so no remux is
      # needed; its poster frame — extracted from the clip — drives both the
      # catalog thumbnail and the player poster through the usual thumbnail
      # pipeline, exactly like the image works above. (Moss-covered tree
      # trunk by Elvis Deane, CC0 1.0 Public Domain Dedication, sourced from
      # Wikimedia Commons.)
      av_work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/sample-video-mods.xml')
      av_poster_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/sample-video-poster.jpg').open_base
      AtlasRb::Work.set_thumbnails(av_work['id'], **ThumbnailCreator.call(base: av_poster_base))
      AtlasRb::Work.metadata(av_work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(av_work['id'], '/home/cerberus/web/spec/fixtures/files/sample-video.mp4', 'sample-video.mp4')
      AtlasRb::Work.complete(av_work['id'])

      # A fourth public image Work so the homepage "Recently Added Items" grid
      # shows a full four-up row (as a populated prod system would) rather than
      # a partial row. Reuses the lake.jpg fixture — visually distinct from the
      # other three recent Works (field / flower / video poster).
      lake_work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/work-lake-mods.xml')
      lake_work_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/lake.jpg').open_base
      AtlasRb::Work.set_thumbnails(lake_work['id'], **ThumbnailCreator.call(base: lake_work_base))
      AtlasRb::Work.metadata(lake_work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(lake_work['id'], '/home/cerberus/web/spec/fixtures/files/lake.jpg', 'lake.jpg')
      AtlasRb::Work.complete(lake_work['id'])

      # Marcom loader fixtures — Communications community → Communications
      # Photo Archive collection → Campus Life (Photographs) collection. The
      # middle collection is what the marcom Loader.root_collection points at;
      # the picker in LoadsController#new queries its children (so a future
      # sibling like "Athletics (Photographs)" appears in the dropdown without
      # any code change). Thumbnails use their own distinct placeholder
      # bases (canyon / forest / waterfall) so the marcom tree doesn't visually
      # duplicate the Northeastern University / Test Collection / What's New
      # seeds in the gallery — these are dev/staging fixtures, not
      # production imagery (canyon = public domain, forest = CC0, waterfall =
      # public domain; all sourced from Wikimedia Commons).
      # Marcom Grouper group seeded onto edit_groups at every level of the
      # community → collection tree so the loader-role test user
      # (NUID 000000003) inherits :update rights on IPTC-deposited Works
      # via Atlas's parent-permission inheritance (WorkCreator copies
      # parent.permissions onto the child). The staff group is auto-
      # prepended by Atlas's permissions= setter; we only add marcom here.
      marcom_group = 'northeastern:drs:repository:loaders:marcom'

      canyon_base    = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/canyon.jpg').open_base
      forest_base    = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/forest.jpg').open_base
      waterfall_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/waterfall.jpg').open_base

      communications = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/communications-mods.xml', depositor: unowned)
      AtlasRb::Community.set_thumbnails(communications['id'], **ThumbnailCreator.call(base: canyon_base))
      AtlasRb::Community.metadata(communications['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [marcom_group] } })

      photo_archive = AtlasRb::Collection.create(communications['id'], '/home/cerberus/web/spec/fixtures/files/communications-photo-archive-mods.xml', depositor: unowned)
      AtlasRb::Collection.set_thumbnails(photo_archive['id'], **ThumbnailCreator.call(base: forest_base))
      AtlasRb::Collection.metadata(photo_archive['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [marcom_group] } })

      campus_life = AtlasRb::Collection.create(photo_archive['id'], '/home/cerberus/web/spec/fixtures/files/campus-life-photographs-mods.xml', depositor: unowned)
      AtlasRb::Collection.set_thumbnails(campus_life['id'], **ThumbnailCreator.call(base: waterfall_base))
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
      library = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/library-mods.xml', depositor: unowned)
      mountain_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/mountain.jpg').open_base
      AtlasRb::Community.set_thumbnails(library['id'], **ThumbnailCreator.call(base: mountain_base))
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

      # A personal workspace collection under Jane's root — what My DRS "My
      # workspace" lists (the workspace is scoped to the personal-root subtree,
      # so institutional collections a person created don't bleed in). Created
      # AS Jane (the reset otherwise runs as admin) so Atlas's creator-owns model
      # stamps her as its depositor: it genuinely belongs to her, in her own
      # space, and so doubles as the named-Person proxy-deposit target — no
      # on_behalf_of workaround needed. A Person is authorized to create within
      # their own personal root.
      if jane['personal_root_id'].present?
        Current.set(nuid: jane['nuid']) do
          working_files = AtlasRb::Collection.create(jane['personal_root_id'],
                                                     '/home/cerberus/web/spec/fixtures/files/jane-working-files-mods.xml')
          AtlasRb::Collection.metadata(working_files['id'], { 'permissions' => { 'read' => ['public'] } })
        end
      end

      # One published work: homed in Jane's personal root, surfaced into the
      # Datasets showcase via the linked-member edge (the conduit). This flips
      # that showcase from hidden-empty to visible in the Library browse and the
      # homepage Featured Content, and populates Jane's My DRS "Published" space.
      datasets = showcases['Datasets']
      if datasets && jane['personal_root_id'].present?
        jane_work = AtlasRb::Work.create(jane['personal_root_id'],
                                         '/home/cerberus/web/spec/fixtures/files/library-dataset-mods.xml',
                                         depositor: jane['nuid'])
        coast_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/coast.jpg').open_base
        AtlasRb::Work.set_thumbnails(jane_work['id'], **ThumbnailCreator.call(base: coast_base))
        AtlasRb::Work.metadata(jane_work['id'], { 'permissions' => { 'read' => ['public'] } })
        AtlasRb::Blob.create(jane_work['id'], '/home/cerberus/web/spec/fixtures/files/coast.jpg', 'coastal-survey.jpg')
        AtlasRb::Work.complete(jane_work['id'])
        AtlasRb::Work.add_linked_member(jane_work['id'], datasets['id'])
      end

      # --- User-guide / UAT fixtures --------------------------------------
      # Each object below unblocks a specific guide walkthrough a fresh seed
      # otherwise can't illustrate. All are homed in the Test Collection so a
      # demoer finds them in one place.

      # Multipage loader (kind: :multipage). Librarian-operated, so it carries
      # no root collection — it picks a destination at upload time (the reason
      # My Loaders must tolerate a nil root_collection). Admins see every
      # loader; giving a non-admin fixture user the loaders:multipage group is
      # an Atlas Grouper seed.
      Loader.find_or_create_by!(slug: 'multipage') do |l|
        l.display_name = 'Multipage Loader'
        l.group        = 'northeastern:drs:repository:loaders:multipage'
        l.kind         = :multipage
      end

      # A multipage Work: one ordered FileSet per page, each with its own IIIF
      # image service for the P3.0 manifest the Tify viewer reads; page 1 also
      # drives the Work-level thumbnail. Mirrors MultipageIngestJob's shape.
      paged_work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/sample-multipage-mods.xml')
      ['multipage/bdr_43889.tif', 'multipage/bdr_43890.tif'].each_with_index do |page, index|
        page_path = "/home/cerberus/web/spec/fixtures/files/#{page}"
        file_set  = AtlasRb::FileSet.create(paged_work['id'], 'image', position: index + 1)
        AtlasRb::FileSet.update(file_set['id'], page_path, original_filename: File.basename(page))
        page_master = MasterJp2.call(path: page_path)
        AtlasRb::FileSet.set_iiif_service(file_set['id'], page_master.gated_base)
        # Page 1's image seeds the Work-level thumbnail (the catalog/gallery tile).
        if index.zero?
          AtlasRb::Work.set_thumbnails(paged_work['id'], **ThumbnailCreator.call(base: page_master.open_base))
        end
      end
      AtlasRb::Work.metadata(paged_work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Work.complete(paged_work['id'])

      # An image Work carrying small/medium/large download renditions, so the
      # download-size picker appears. IiifAssetsJob registers thumbnails + the
      # gated IIIF service and, given derivative_widths, the S/M/L renditions —
      # the IPTC loader's default-on path. Ratio widths never upscale, so the
      # source dimensions don't matter; perform_now keeps the Rational widths
      # intact (ActiveJob argument serialization would reject them).
      sizes_work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/sample-image-sizes-mods.xml')
      AtlasRb::Work.metadata(sizes_work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(sizes_work['id'], '/home/cerberus/web/spec/fixtures/files/beach.jpg', 'beach.jpg')
      IiifAssetsJob.perform_now(sizes_work['id'], '/home/cerberus/web/spec/fixtures/files/beach.jpg',
                                derivative_widths: DerivativeCreator::DEFAULT_WIDTHS)
      AtlasRb::Work.complete(sizes_work['id'])

      # A playable audio Work — the only audio fixture, so the audio-player path
      # can be shown. mp3 is a browser-safe codec, so it streams through the
      # same Range media endpoint with no remux; audio carries no poster.
      audio_work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/sample-audio-mods.xml')
      audio_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/all_star_trio.jpg').open_base
      AtlasRb::Work.set_thumbnails(audio_work['id'], **ThumbnailCreator.call(base: audio_base))
      AtlasRb::Work.metadata(audio_work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(audio_work['id'], '/home/cerberus/web/spec/fixtures/files/sample-audio.mp3', 'sample-audio.mp3')
      AtlasRb::Work.complete(audio_work['id'])

      # An Office-document Work whose deposit exercises the Word → PDF rendition
      # + first-page thumbnail enrichment. The docx is staged under uploads_root
      # because PdfRenditionJob writes its PDF beside the source (the fixture
      # path directly would clobber the checked-in example.pdf); the job runs
      # async so soffice's fresh-profile retry can't abort the reset.
      doc_work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/sample-document-mods.xml')
      AtlasRb::Work.metadata(doc_work['id'], { 'permissions' => { 'read' => ['public'] } })
      staged_dir = File.join(Rails.application.config.x.cerberus.uploads_root, doc_work['id'])
      FileUtils.mkdir_p(staged_dir)
      staged_doc = File.join(staged_dir, 'example.docx')
      FileUtils.cp('/home/cerberus/web/spec/fixtures/files/example.docx', staged_doc)
      AtlasRb::Blob.create(doc_work['id'], staged_doc, 'example.docx')
      AtlasRb::Work.complete(doc_work['id'])
      PdfRenditionJob.perform_later(doc_work['id'], staged_doc, SecureRandom.uuid)

      # A withdrawn (tombstoned) Work so the admin restore registry has an entry
      # to demonstrate the restore path. Tombstoning needs a completed Work, so
      # it is built normally and then withdrawn.
      withdrawn_work = AtlasRb::Work.create(collection['id'], '/home/cerberus/web/spec/fixtures/files/sample-withdrawn-mods.xml')
      withdrawn_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/gorge.jpg').open_base
      AtlasRb::Work.set_thumbnails(withdrawn_work['id'], **ThumbnailCreator.call(base: withdrawn_base))
      AtlasRb::Work.metadata(withdrawn_work['id'], { 'permissions' => { 'read' => ['public'] } })
      AtlasRb::Blob.create(withdrawn_work['id'], '/home/cerberus/web/spec/fixtures/files/gorge.jpg', 'gorge.jpg')
      AtlasRb::Work.complete(withdrawn_work['id'])
      AtlasRb::Work.tombstone(withdrawn_work['id'])

      # --- Group-permission UAT fixtures -----------------------------------
      # A representative slice of the Group table's ~75 real Grouper
      # identifiers, wired onto fresh Communities/Collections plus a matching
      # cast of :standard-role users, so a Librarian exploring the group
      # permissions editor (app/views/shared/_group_permissions.html.haml)
      # and the group-name admin (Admin::GroupsController) has real, varied
      # data to click through instead of the single marcom example above.
      # Each pair below exercises a distinct read/edit gating shape: a
      # self-managed private space (read+edit both gated to one group),
      # edit-gate-only, multi-group edit (two independent groups), and
      # read-gate-only. AtlasRb::System::User.find_or_create is the same call
      # the SSO callback uses (AtlasController#process_find_or_create); it
      # takes no role, and Atlas's users table defaults role to :standard, so
      # these fixtures land at the one human role tier no prior fixture NUID
      # (000000001-4, all guest/privileged/loader/admin) represents.
      archives_group    = 'northeastern:drs:library:archives'
      nupd_media_group  = 'northeastern:drs:nupd:media'
      law_library_group = 'northeastern:drs:school_of_law:law_library:staff'
      crrj_group        = 'northeastern:drs:school_of_law:crrj:staff'
      l2_group          = 'northeastern:drs:library:licensed_resources:l2'

      # One roster drives both halves of each fixture: the loginable user here,
      # and the Person (with its personal root) further down. They have to stay
      # in step — a user without a Person gets an empty My DRS — so they are
      # written from the same list rather than two parallel blocks that can
      # drift apart.
      group_fixtures = [
        { nuid: '000000010', email: 'archives.reader.fixture@northeastern.edu',
          name: 'Archives Reader (DRS Fixture)', group: archives_group },
        { nuid: '000000011', email: 'nupd.media.fixture@northeastern.edu',
          name: 'NUPD Media Staffer (DRS Fixture)', group: nupd_media_group },
        { nuid: '000000012', email: 'law.library.fixture@northeastern.edu',
          name: 'Law Library Staffer (DRS Fixture)', group: law_library_group },
        { nuid: '000000013', email: 'crrj.staff.fixture@northeastern.edu',
          name: 'CRRJ Staffer (DRS Fixture)', group: crrj_group },
        { nuid: '000000014', email: 'l2.reader.fixture@northeastern.edu',
          name: 'Licensed Resources Reader (DRS Fixture)', group: l2_group },
        # No group, and below no affiliation either — the control for what a
        # plain depositor sees: a workspace, but no publish-to-my-community fork.
        { nuid: '000000015', email: 'standard.fixture@northeastern.edu',
          name: 'No-Groups Standard User (DRS Fixture)', group: nil }
      ]

      group_fixtures.each do |fixture|
        AtlasRb::System::User.find_or_create(email: fixture[:email], nuid: fixture[:nuid],
                                             name: fixture[:name], affiliation: 'staff',
                                             groups: [fixture[:group]].compact)
      end

      # Each shape below gets its own base image, distinct from every other
      # thumbnail in this task (including gorge/mountain/coast/beach above),
      # so the gallery/permissions-picker views don't show the same tile
      # twice. All four are US-government or public-domain-dedicated works
      # sourced via Flickr: cliff.jpg (Devil's Slide Hiking Trail, Pacifica,
      # by John William Hammond, Public Domain Mark 1.0), marsh.jpg (Salt
      # marsh landscape, US Fish & Wildlife Service Northeast Region, US
      # government work), valley.jpg (Hood River Valley Orchards, Oregon, by
      # Bonnie Moreland, Public Domain Mark 1.0), and dunes.jpg (Dune Ridge,
      # Great Sand Dunes National Park, by Patrick Myers/NPS, US government
      # work).

      # A: self-managed private space — read AND edit gated to archives staff,
      # the only fixture pair above with no public read at all.
      archives_community = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/archives-community-mods.xml', depositor: unowned)
      archives_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/cliff.jpg').open_base
      AtlasRb::Community.set_thumbnails(archives_community['id'], **ThumbnailCreator.call(base: archives_base))
      AtlasRb::Community.metadata(archives_community['id'], { 'permissions' => { 'read' => [archives_group], 'edit' => [archives_group] } })

      reading_room = AtlasRb::Collection.create(archives_community['id'], '/home/cerberus/web/spec/fixtures/files/archives-reading-room-mods.xml', depositor: unowned)
      AtlasRb::Collection.set_thumbnails(reading_room['id'], **ThumbnailCreator.call(base: archives_base))
      AtlasRb::Collection.metadata(reading_room['id'], { 'permissions' => { 'read' => [archives_group], 'edit' => [archives_group] } })

      # B: edit-gate-only, a second unit beyond marcom — read stays public.
      public_safety = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/public-safety-community-mods.xml', depositor: unowned)
      public_safety_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/marsh.jpg').open_base
      AtlasRb::Community.set_thumbnails(public_safety['id'], **ThumbnailCreator.call(base: public_safety_base))
      AtlasRb::Community.metadata(public_safety['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [nupd_media_group] } })

      nupd_media = AtlasRb::Collection.create(public_safety['id'], '/home/cerberus/web/spec/fixtures/files/nupd-incident-media-mods.xml', depositor: unowned)
      AtlasRb::Collection.set_thumbnails(nupd_media['id'], **ThumbnailCreator.call(base: public_safety_base))
      AtlasRb::Collection.metadata(nupd_media['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [nupd_media_group] } })

      # C: multi-group edit — two independent groups both granted edit on one
      # Collection, so removing one in the permissions UI strips only that
      # group's editors, not the other's.
      school_of_law = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/school-of-law-community-mods.xml', depositor: unowned)
      law_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/valley.jpg').open_base
      AtlasRb::Community.set_thumbnails(school_of_law['id'], **ThumbnailCreator.call(base: law_base))
      AtlasRb::Community.metadata(school_of_law['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [law_library_group, crrj_group] } })

      law_crrj_collection = AtlasRb::Collection.create(school_of_law['id'], '/home/cerberus/web/spec/fixtures/files/law-crrj-collection-mods.xml', depositor: unowned)
      AtlasRb::Collection.set_thumbnails(law_crrj_collection['id'], **ThumbnailCreator.call(base: law_base))
      AtlasRb::Collection.metadata(law_crrj_collection['id'], { 'permissions' => { 'read' => ['public'], 'edit' => [law_library_group, crrj_group] } })

      # D: read-gate-only, the mirror of B — edit stays staff-only.
      licensed_resources = AtlasRb::Community.create(community['id'], '/home/cerberus/web/spec/fixtures/files/licensed-resources-community-mods.xml', depositor: unowned)
      licensed_base = MasterJp2.call(path: '/home/cerberus/web/spec/fixtures/files/dunes.jpg').open_base
      AtlasRb::Community.set_thumbnails(licensed_resources['id'], **ThumbnailCreator.call(base: licensed_base))
      AtlasRb::Community.metadata(licensed_resources['id'], { 'permissions' => { 'read' => [l2_group] } })

      l2_archive = AtlasRb::Collection.create(licensed_resources['id'], '/home/cerberus/web/spec/fixtures/files/l2-dataset-archive-mods.xml', depositor: unowned)
      AtlasRb::Collection.set_thumbnails(l2_archive['id'], **ThumbnailCreator.call(base: licensed_base))
      AtlasRb::Collection.metadata(l2_archive['id'], { 'permissions' => { 'read' => [l2_group] } })

      # The Person half of each group fixture. My DRS resolves the depositor's
      # workspace and publish target through Person#personal_root_id
      # (DepositorContext#deposit_person), so a loginable user with no Person
      # lands on an empty My DRS and can't exercise it at all — Person.create is
      # what mints that personal root.
      #
      # Down here rather than beside the users because affiliation needs the
      # communities built above. Each fixture is affiliated with the community
      # its own Grouper group gates, which is what turns "publish to my
      # community" into a real choice instead of an empty one.
      affiliations = { archives_group => archives_community, nupd_media_group => public_safety,
                       law_library_group => school_of_law, crrj_group => school_of_law,
                       l2_group => licensed_resources }

      group_fixtures.each do |fixture|
        person = AtlasRb::Person.create(nuid: fixture[:nuid], display_name: fixture[:name])
        home = affiliations[fixture[:group]]
        AtlasRb::Person.add_affiliation(person['id'], home['id']) if home
      end
    end

    # Seed usage analytics so /admin/impressions is populated for demos and UAT.
    # Runs after the object seed has indexed into Solr (it keys on the Works now
    # present there) and writes only to Cerberus's own analytics tables.
    ImpressionSeeder.call
  end

  desc 'Seed representative usage impressions for the Usage Analytics dashboard'
  task impressions: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    count = ImpressionSeeder.call
    puts "Seeded #{count} impressions across the indexed Works."
  end

  desc 'Clean Solr and Atlas (AR tables are reset by db:replant)'
  task clean: :environment do
    raise "Wrong env - #{Rails.env} - must be development" unless Rails.env.development? || Rails.env.staging?

    Blacklight.default_index.connection.delete_by_query '*:*'
    Blacklight.default_index.connection.commit
    AtlasRb::Reset.clean
  end
end
