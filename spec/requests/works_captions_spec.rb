# frozen_string_literal: true

require 'rails_helper'

# The Captions field on the Work edit form. Like the other resource-write specs
# this runs against the live Atlas test backend — a real Work with a real edit ACL
# granted to the staff group — so the :edit gate the field rides is exercised
# end-to-end. The attach itself is deferred to CaptionJob (asserted enqueued via
# the test adapter), so no Blob is written here.
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

  # Atlas's Blob delete is admin-only and takes every earlier revision with it,
  # so Cerberus offers it only to admins.
  describe 'removing the caption file' do
    let(:admin) do
      User.new(email: 'admin@example.com', password: 'password', nuid: '000000004',
               name: 'Ad, Min', role: 'admin', groups: [Permissions::STAFF_EDIT_GROUP])
    end
    let(:caption) { AtlasRb::Mash.new(noid: 'cap-1', mime_type: 'text/vtt', language: 'es', track_label: 'Español') }
    let(:other_blob) { AtlasRb::Mash.new(noid: 'vid-1', mime_type: 'video/mp4') }

    before do
      allow(AtlasRb::Work).to receive(:assets).and_call_original
      allow(AtlasRb::Work).to receive(:assets).with(work.id, anything).and_return([other_blob, caption])
      allow(AtlasRb::Blob).to receive(:destroy).and_return(instance_double(Faraday::Response, success?: true))
    end

    it 'deletes the chosen caption Blob for an admin and returns to the edit page' do
      sign_in admin
      delete caption_work_path(work.id), params: { caption_id: 'cap-1' }

      expect(AtlasRb::Blob).to have_received(:destroy).with('cap-1', nuid: '000000004')
      expect(response).to redirect_to(edit_work_path(work.id))
      expect(flash[:notice]).to eq('Español caption file removed.')
    end

    # The id arrives from the form, so it must name one of this Work's captions.
    it 'refuses an id that is not one of the work\'s captions, and deletes nothing' do
      sign_in admin
      delete caption_work_path(work.id), params: { caption_id: 'vid-1' }

      expect(flash[:alert]).to eq('This work has no such caption file.')
      expect(AtlasRb::Blob).not_to have_received(:destroy)
    end

    it 'refuses an editor who is not an admin, and deletes nothing' do
      sign_in editor
      delete caption_work_path(work.id), params: { caption_id: 'cap-1' }

      expect(response).to have_http_status(:forbidden)
      expect(AtlasRb::Blob).not_to have_received(:destroy)
    end

    it 'says so when the work has no caption file' do
      allow(AtlasRb::Work).to receive(:assets).with(work.id, anything).and_return([])
      sign_in admin
      delete caption_work_path(work.id), params: { caption_id: 'cap-1' }

      expect(flash[:alert]).to eq('This work has no such caption file.')
      expect(AtlasRb::Blob).not_to have_received(:destroy)
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
