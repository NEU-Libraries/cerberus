# frozen_string_literal: true

require 'rails_helper'

# The Captions field on the Work edit form. Like the other resource-write specs
# this runs against the live Atlas test backend — a real Work with a real edit ACL
# granted to the staff group — so the :edit gate the field rides is exercised
# end-to-end. The attach itself is deferred to CaptionJob (asserted enqueued via
# the test adapter). Only the removal examples write a caption Blob, to watch
# Atlas withdraw and restore it.
RSpec.describe 'Works captions', type: :request do
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }
  let(:work)       { AtlasRb::Work.create(collection.id, "#{fixtures}/work-mods.xml", nuid: '000000004') }

  let(:editor) do
    User.new(email: 'editor@example.com', password: 'password', nuid: '000000002',
             name: 'Ed, Itor', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  let(:outsider) do
    User.new(email: 'outsider@example.com', password: 'password',
             name: 'Out, Sider', role: 'standard', groups: ['randos'])
  end

  def upload(name)
    Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/files', name))
  end

  # The descriptive fields ride along because the Captions field sits in the
  # Metadata tab's form, which always posts them.
  def submit(file, language: 'en', **other)
    patch work_path(work.id), params: {
      work:    { title: 'A river runs past the field', keywords: ['river'] },
      caption: file, caption_language: language, **other
    }
  end

  # The Work is public as well as staff-editable, so the :edit gate is what the
  # authorization examples exercise. Atlas gates reads on the resource's own ACL,
  # so a private Work is invisible to a guest and the request 404s before
  # reaching the gate — which proves the resource is hidden, not that the write
  # is refused. Widening runs top-down because Atlas refuses a resource more
  # visible than its container. Read and edit go in one call, since Atlas assigns
  # the edit grants unconditionally from the payload.
  before do
    publicize_ancestry!(community: community, collection: collection)
    AtlasRb::Resource.set_permissions(work.id,
                                      { 'read' => ['public'],
                                        'edit' => [Permissions::STAFF_EDIT_GROUP] },
                                      nuid: '000000004')
  end

  # Removal withdraws the caption's FileSet, so it is reversible, and Atlas
  # allows it to admins and delegated admins only.
  describe 'removing and restoring a caption file' do
    let(:admin) do
      User.new(email: 'admin@example.com', password: 'password', nuid: '000000004',
               name: 'Ad, Min', role: 'admin', groups: [Permissions::STAFF_EDIT_GROUP])
    end
    let(:delegate) do
      User.new(email: 'delegate@example.com', password: 'password', nuid: '000000002',
               name: 'Del, Egate', role: 'privileged',
               groups: [Permissions::STAFF_EDIT_GROUP, Permissions::ADMIN_GROUP])
    end

    def live_captions
      CaptionTrack.all(AtlasRb::Work.assets(work.id, nuid: '000000004'))
    end

    def removed_captions
      CaptionTrack.all(AtlasRb::Work.withdrawn_assets(work.id, nuid: '000000004'))
    end

    # Against the test Atlas, not stubs: the whole point is that Atlas keeps
    # the file and names it in withdrawn_assets, which a stub would only assert.
    context 'against Atlas' do
      before do
        AtlasRb::Blob.create(work.id, Rails.root.join('spec/fixtures/files/captions.vtt').to_s, 'es.vtt',
                             language: 'es', track_label: 'Español', nuid: '000000004')
      end

      it 'withdraws the caption for a delegated admin, then restores it' do
        sign_in delegate
        caption = live_captions.sole

        delete caption_work_path(work.id), params: { caption_id: caption.noid }
        expect(flash[:notice]).to eq('Español caption file removed. It can be restored below.')
        expect(live_captions).to be_empty
        expect(removed_captions.map(&:noid)).to eq([caption.noid])

        post restore_caption_work_path(work.id), params: { file_set_id: caption.file_set }
        expect(flash[:notice]).to eq('Español caption file restored.')
        expect(live_captions.map(&:noid)).to eq([caption.noid])
        expect(removed_captions).to be_empty
      end

      # The edit page offers Captions only on a finished Work with a recording.
      it 'lists the removed caption on the edit page, with Restore' do
        AtlasRb::Blob.create(work.id, Rails.root.join('spec/fixtures/files/sample-video.mp4').to_s, 'sample-video.mp4',
                             nuid: '000000004')
        AtlasRb::Work.complete(work.id, nuid: '000000004')
        sign_in admin
        caption = live_captions.sole
        delete caption_work_path(work.id), params: { caption_id: caption.noid }

        get edit_work_path(work.id)
        expect(response.body).to include('Removed caption files')
        expect(response.parsed_body.css("button[form='restore-caption'][value='#{caption.file_set}']")).to be_present
      end
    end

    context 'with Atlas stubbed' do
      let(:caption) do
        AtlasRb::Mash.new(noid: 'cap-1', file_set: 'fs-1', mime_type: 'text/vtt', language: 'es', track_label: 'Español')
      end
      let(:other_blob) { AtlasRb::Mash.new(noid: 'vid-1', file_set: 'fs-v', mime_type: 'video/mp4') }
      let(:ok) { instance_double(Faraday::Response, success?: true) }

      before do
        allow(AtlasRb::Work).to receive(:assets).and_call_original
        allow(AtlasRb::Work).to receive(:assets).with(work.id, anything).and_return([other_blob, caption])
        allow(AtlasRb::Work).to receive(:withdrawn_assets).and_return([])
        allow(AtlasRb::Resource).to receive(:tombstone).and_return(ok)
        allow(AtlasRb::Admin::Resource).to receive(:restore).and_return(ok)
      end

      # The id arrives from the form, so it must name one of this Work's captions.
      it 'refuses an id that is not one of the work\'s captions, and withdraws nothing' do
        sign_in admin
        delete caption_work_path(work.id), params: { caption_id: 'vid-1' }

        expect(flash[:alert]).to eq('This work has no such caption file.')
        expect(AtlasRb::Resource).not_to have_received(:tombstone)
      end

      it 'refuses an editor below the delegate tier, and withdraws or restores nothing' do
        sign_in editor
        delete caption_work_path(work.id), params: { caption_id: 'cap-1' }
        expect(response).to have_http_status(:forbidden)

        post restore_caption_work_path(work.id), params: { file_set_id: 'fs-1' }
        expect(response).to have_http_status(:forbidden)

        expect(AtlasRb::Resource).not_to have_received(:tombstone)
        expect(AtlasRb::Admin::Resource).not_to have_received(:restore)
      end

      it 'refuses to restore a file set that is not one of the work\'s removed captions' do
        sign_in admin
        post restore_caption_work_path(work.id), params: { file_set_id: 'fs-elsewhere' }

        expect(flash[:alert]).to eq('This work has no such removed caption file.')
        expect(AtlasRb::Admin::Resource).not_to have_received(:restore)
      end

      # Two live tracks in one language could not be told apart in the player.
      it 'refuses to restore a caption whose language already has a live one' do
        removed = AtlasRb::Mash.new(noid: 'cap-0', file_set: 'fs-0', mime_type: 'text/vtt', language: 'es',
                                    track_label: 'Español')
        allow(AtlasRb::Work).to receive(:withdrawn_assets).and_return([removed])
        sign_in admin
        post restore_caption_work_path(work.id), params: { file_set_id: 'fs-0' }

        expect(flash[:alert]).to eq('This work already has a Español caption file. Remove it first, then restore this one.')
        expect(AtlasRb::Admin::Resource).not_to have_received(:restore)
      end

      it 'says so when Atlas refuses the withdrawal' do
        allow(AtlasRb::Resource).to receive(:tombstone).and_return(instance_double(Faraday::Response, success?: false))
        sign_in admin
        delete caption_work_path(work.id), params: { caption_id: 'cap-1' }

        expect(flash[:alert]).to eq('The caption file could not be removed.')
      end
    end
  end

  describe 'authorization' do
    it 'forbids the unauthenticated and enqueues nothing' do
      expect { submit(upload('captions.vtt')) }.not_to have_enqueued_job(CaptionJob)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids an authenticated non-editor and enqueues nothing' do
      sign_in outsider
      expect { submit(upload('captions.vtt')) }.not_to have_enqueued_job(CaptionJob)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'as an in-group editor' do
    before { sign_in editor }

    it 'stages the upload and queues CaptionJob with the chosen language' do
      expect { submit(upload('captions.vtt'), language: 'es') }
        .to have_enqueued_job(CaptionJob)
        .with(work.id, kind_of(String), 'captions.vtt', kind_of(String),
              'language' => 'es', 'track_label' => 'Español')
    end

    it 'queues an Other language from its tag and label' do
      expect do
        submit(upload('captions.vtt'), language: 'other', caption_language_tag: 'es-MX',
                                       caption_language_label: 'Español (México)')
      end.to have_enqueued_job(CaptionJob)
        .with(work.id, kind_of(String), 'captions.vtt', kind_of(String),
              'language' => 'es-MX', 'track_label' => 'Español (México)')
    end

    # Atlas would refuse a malformed tag with 422 only after the job ran, where
    # nobody would see it.
    it 'refuses a malformed Other tag at the form, says why, and queues nothing' do
      expect do
        submit(upload('captions.vtt'), language: 'other', caption_language_tag: 'Spanish!',
                                       caption_language_label: 'Español')
      end.not_to have_enqueued_job(CaptionJob)
      expect(flash[:alert]).to eq(CaptionTrack::REFUSED_LANGUAGE)
    end

    # A browser <track> reads WebVTT only, and this application converts nothing,
    # so an .srt is refused with a message rather than stored as a file no player
    # can use. v1 accepted one because its Flash player parsed the format itself.
    it 'refuses a .srt upload, says why, and queues nothing' do
      expect { submit(upload('captions.srt')) }.not_to have_enqueued_job(CaptionJob)
      expect(flash[:alert]).to include('WebVTT')
    end

    # The refusal must not cost the depositor the title edit that came with it.
    it 'still saves the descriptive fields when it refuses the file' do
      submit(upload('captions.srt'))
      expect(AtlasRb::Work.mods(work.id, 'xml')).to include('A river runs past the field')
    end

    it 'queues nothing when the form carries no caption' do
      expect do
        patch work_path(work.id), params: { work: { title: 'A river', keywords: ['river'] } }
      end.not_to have_enqueued_job(CaptionJob)
    end
  end

  # This file leaves Works waiting on a depositor, which the admin triage registry
  # lists. Purging them keeps that registry's own specs measuring its filter rather
  # than the size of the suite (see spec/support/work_cleanup.rb).
  after(:all) { purge_stuck_works! }
end
