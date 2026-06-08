# frozen_string_literal: true

require 'rails_helper'

# The Rights / MODS history diff pages, reached from the audit-log "View"
# button. Admin-gated (same audience as the History tab). atlas_rb is stubbed
# so these exercise the Cerberus controller/view wiring, not Atlas.
RSpec.describe 'Histories', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  let(:resource_id) { 'w-789' }

  def found(klass: 'Work', title: 'My Work')
    OpenStruct.new(klass: klass, resource: OpenStruct.new(title: title))
  end

  def history_mash(events)
    AtlasRb::Mash.new('resource_id' => resource_id, 'events' => events)
  end

  def perm_event(at:, before:, after:)
    { 'action' => 'update', 'change_type' => 'permissions',
      'payload' => { 'before' => before, 'after' => after },
      'actor_nuid' => '000000004', 'occurred_at' => at, 'on_behalf_of_nuid' => nil }
  end

  before { allow(AtlasRb::Resource).to receive(:find).with(resource_id).and_return(found) }

  describe 'auth gate' do
    it 'forbids privileged non-admins' do
      sign_in staff_user
      get rights_history_path(resource_id)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids the unauthenticated' do
      get rights_history_path(resource_id)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET rights_history (as admin)' do
    before { sign_in admin_user }

    it 'lists permission changes with a before/after diff, skipping non-permission events' do
      events = [
        perm_event(at: '2026-05-26T12:00:00Z', before: { 'read' => ['staff'] }, after: { 'read' => %w[public staff] }),
        { 'action' => 'update', 'change_type' => 'metadata', 'payload' => { 'source' => 'mods' },
          'actor_nuid' => '000000004', 'occurred_at' => '2026-05-25T00:00:00Z', 'on_behalf_of_nuid' => nil }
      ]
      allow(AtlasRb::Resource).to receive(:history).and_return(history_mash(events))
      get rights_history_path(resource_id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Access-control changes')
      expect(response.body).to include('rights-diff__pill--added">public')
    end

    it 'shows the empty state when there are no permission events' do
      allow(AtlasRb::Resource).to receive(:history).and_return(history_mash([]))
      get rights_history_path(resource_id)
      expect(response.body).to include('No permission changes recorded')
    end

    it 'isolates the ?at deep-linked event on its own page (one event per page)' do
      events = Array.new(25) { |i| perm_event(at: format('2026-05-%02dT00:00:00Z', i + 1), before: {}, after: { 'read' => ["g#{i}"] }) }
      allow(AtlasRb::Resource).to receive(:history).and_return(history_mash(events))
      get rights_history_path(resource_id, at: events[22]['occurred_at'])
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('g22')      # the deep-linked event renders
      expect(response.body).not_to include('g21')  # neighbours are NOT stacked alongside it
      expect(response.body).not_to include('g23')
    end

    it 'renders a Previous/Next walker stepping between changes' do
      events = Array.new(3) { |i| perm_event(at: format('2026-05-%02dT00:00:00Z', i + 1), before: {}, after: { 'read' => ["g#{i}"] }) }
      allow(AtlasRb::Resource).to receive(:history).and_return(history_mash(events))
      get rights_history_path(resource_id, at: events[1]['occurred_at']) # middle event → page 2 of 3
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Permission change navigation') # the walker nav
      expect(response.body).to include('Change 2 of 3')                # position indicator
      expect(response.body).to include('Reverse chronological')        # ordering subtitle
      expect(response.body).to include('g1')
      expect(response.body).not_to include('g0')
      expect(response.body).not_to include('g2')
    end

    it 'hides the list chrome (position indicator, ordering, walker) for a lone change' do
      events = [perm_event(at: '2026-05-26T12:00:00Z', before: {}, after: { 'read' => ['public'] })]
      allow(AtlasRb::Resource).to receive(:history).and_return(history_mash(events))
      get rights_history_path(resource_id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Access-control changes')       # title still shows
      expect(response.body).not_to include('Reverse chronological')
      expect(response.body).not_to include('Permission change navigation')
      expect(response.body).not_to match(/Change \d+ of \d+/)
    end
  end

  describe 'GET mods_history (as admin)' do
    before { sign_in admin_user }

    let(:versions) do
      [{ 'version_id' => 'v5', 'created' => '2026-05-26T12:00:00Z', 'actor_nuid' => '000000004',
         'on_behalf_of_nuid' => nil, 'source' => 'mods', 'note' => nil },
       { 'version_id' => 'v3', 'created' => '2026-05-20T09:00:00Z', 'actor_nuid' => '000000002',
         'on_behalf_of_nuid' => nil, 'source' => 'mods', 'note' => nil }]
    end

    def mods_mash(vers)
      AtlasRb::Mash.new('resource_id' => resource_id, 'versions' => vers)
    end

    it 'defaults to newest vs previous and renders a line diff' do
      allow(AtlasRb::Resource).to receive(:mods_versions).and_return(mods_mash(versions))
      allow(AtlasRb::Resource).to receive(:mods_version).with(resource_id, 'v3', nuid: anything)
                                                        .and_return('<mods><titleInfo><title>Old</title></titleInfo></mods>')
      allow(AtlasRb::Resource).to receive(:mods_version).with(resource_id, 'v5', nuid: anything)
                                                        .and_return('<mods><titleInfo><title>New</title></titleInfo></mods>')
      get mods_history_path(resource_id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('class="diff"')
      expect(response.body).to include('New')
    end

    it 'shows the empty state when no versions exist' do
      allow(AtlasRb::Resource).to receive(:mods_versions).and_return(mods_mash([]))
      get mods_history_path(resource_id)
      expect(response.body).to include('No descriptive-metadata versions recorded')
    end
  end

  describe 'polymorphism across resource types' do
    before { sign_in admin_user }

    %w[Work Collection Community].each do |klass|
      it "serves #{klass} rights history through the one flat route" do
        allow(AtlasRb::Resource).to receive(:find).with(resource_id).and_return(found(klass: klass))
        allow(AtlasRb::Resource).to receive(:history).and_return(history_mash([]))
        get rights_history_path(resource_id)
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
