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
  def submit(file)
    patch work_path(work.id), params: {
      work:    { title: 'A river runs past the field', keywords: ['river'] },
      caption: file
    }
  end

  before do
    AtlasRb::Work.metadata(work.id, { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } },
                           nuid: '000000004')
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

    it 'stages the upload and queues CaptionJob' do
      expect { submit(upload('captions.vtt')) }
        .to have_enqueued_job(CaptionJob).with(work.id, kind_of(String), 'captions.vtt', kind_of(String))
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
