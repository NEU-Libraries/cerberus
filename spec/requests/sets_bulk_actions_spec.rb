# frozen_string_literal: true

require 'rails_helper'

# The Set edit page's Sentinel tab. Runs against the real test Atlas like the
# other Set specs: a real Compilation is created, so the curator gate and the
# Set load are exercised end to end. The sweeps themselves are specced at the job
# level; this file covers the HTTP surface — who is offered the tab, who may
# POST, what gets enqueued, and how a rejected policy comes back.
RSpec.describe 'Sets bulk actions', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:staff) { Permissions::STAFF_EDIT_GROUP }
  let(:admin_group) { Permissions::ADMIN_GROUP }

  # The operator tier: a full Atlas admin, and the devolved tier (:privileged
  # plus the admin group). Both may sweep.
  let(:admin) do
    User.new(email: 'admin@example.com', password: 'password', nuid: '000000004',
             name: 'Ad, Min', role: 'admin', groups: [staff])
  end
  let(:devolved) do
    User.new(email: 'devolved@example.com', password: 'password', nuid: '000000002',
             name: 'Dev, Olved', role: 'privileged', groups: [staff, admin_group])
  end
  # A curator who owns the Set but is not an operator. Owning a Set says nothing
  # about the Works a recipe reaches, which is the whole point of the gate.
  let(:owner) do
    User.new(email: 'owner@example.com', password: 'password', nuid: '000000002',
             name: 'Own, Er', role: 'privileged', groups: [staff])
  end

  def make_set(title = 'Field Notes')
    AtlasRb::Compilation.create(title, nuid: '000000002')
  end

  let(:set) { make_set }

  before do
    allow(SetSentinelApplyJob).to receive(:perform_later)
  end

  def saved
    Sentinel.find_by(target_id: set['id'])
  end

  describe 'who is offered the tab' do
    it 'shows the Sentinel tab to a full admin' do
      sign_in admin
      get "/sets/#{set['id']}/edit"

      expect(response.body).to include('sentinel-tab')
    end

    it 'shows it to the devolved tier' do
      sign_in devolved
      get "/sets/#{set['id']}/edit"

      expect(response.body).to include('sentinel-tab')
    end

    it 'does not show it to a curator who merely owns the set' do
      sign_in owner
      get "/sets/#{set['id']}/edit"

      expect(response.body).not_to include('sentinel-tab')
    end
  end

  describe 'the write gate' do
    it 'refuses apply to a non-operator' do
      sign_in owner
      post "/sets/#{set['id']}/apply_sentinel"

      expect(response).to have_http_status(:forbidden)
      expect(SetSentinelApplyJob).not_to have_received(:perform_later)
    end

    it 'refuses the policy write to a non-operator' do
      sign_in owner
      patch "/sets/#{set['id']}/sentinel", params: { work_access: { visibility: 'public' } }

      expect(response).to have_http_status(:forbidden)
      expect(saved).to be_nil
    end

    it 'redirects an anonymous visitor to sign in' do
      post "/sets/#{set['id']}/apply_sentinel"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'applying the policy' do
    it 'refuses to sweep when no policy has been saved' do
      sign_in admin
      post "/sets/#{set['id']}/apply_sentinel"

      expect(SetSentinelApplyJob).not_to have_received(:perform_later)
      expect(flash[:alert]).to include('Save the Sentinel')
    end

    it 'enqueues the sweep once a policy exists' do
      Sentinel.create!(target_id: set['id'], policy: { 'original' => [staff] })
      sign_in admin
      post "/sets/#{set['id']}/apply_sentinel"

      expect(SetSentinelApplyJob).to have_received(:perform_later).with(set_noid: set['id'])
      expect(response).to redirect_to(edit_set_path(set['id'], tab: 'sentinel'))
    end
  end

  describe 'authoring the policy' do
    it 'saves a restricted tier' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel", params: { sentinel: { original: { mode: 'restrict', groups: [staff] } } }

      expect(saved.policy).to eq({ 'original' => [staff] })
      expect(saved.work_access).to be_nil
      expect(response).to redirect_to(edit_set_path(set['id'], tab: 'sentinel'))
    end

    # A Set is not a container, so an unrestricted tier is omitted rather than
    # written as ['public'] — an omitted tier rides each Work at apply time,
    # which is the only thing that works across a Set of mixed visibility.
    it 'omits an unrestricted tier instead of claiming public' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { sentinel: { small: { mode: 'public' }, original: { mode: 'restrict', groups: [staff] } } }

      expect(saved.policy).to eq({ 'original' => [staff] })
    end

    it 'saves a visibility, and leaves the groups alone under keep' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { work_access: { visibility: 'public', grants_mode: 'keep',
                                     permissions: { '1' => { group_id: admin_group, ability: 'read' } } } }

      expect(saved.work_access).to eq('visibility' => 'public')
    end

    it 'saves replacement grants, skipping the blank entry row and repeats' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { work_access: { visibility: '', grants_mode: 'replace',
                                     permissions: { '1'   => { group_id: admin_group, ability: 'read' },
                                                    '2'   => { group_id: admin_group, ability: 'read' },
                                                    '3'   => { group_id: staff, ability: 'edit' },
                                                    'new' => { group_id: '', ability: 'read' } } } }

      expect(saved.work_access).to eq('grants' => { 'read' => [admin_group], 'edit' => [staff] })
    end

    it 'saves an empty replacement, which removes every group' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel", params: { work_access: { grants_mode: 'replace' } }

      expect(saved.work_access).to eq('grants' => { 'read' => [], 'edit' => [] })
    end

    it 'records that derivative access is to be left alone' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { sentinel: { derivatives_mode: 'keep' }, work_access: { visibility: 'private' } }

      expect(saved.derivatives_enabled).to be(false)
    end

    it 'shows what Apply will do, and warns before a widening' do
      Sentinel.create!(target_id: set['id'], policy: {}, derivatives_enabled: false,
                       work_access: { 'visibility' => 'public' })
      sign_in admin
      get "/sets/#{set['id']}/edit", params: { tab: 'sentinel' }

      pane = response.parsed_body.at_css('#sentinel')
      expect(pane.text).to include('Every work is made public', 'This makes material public')
      expect(pane.text).not_to include('derivative access is set to the policy')
    end

    it 'refuses a policy that widens as resolution grows, and re-renders the ladder' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { sentinel: { small:    { mode: 'restrict', groups: [] },
                                  original: { mode: 'restrict', groups: [staff] } } }

      # Monotonicity is a property of the ladder, so it still applies without a
      # container: original must not be more open than small.
      expect(response).to have_http_status(:unprocessable_content)
      expect(saved).to be_nil
    end

    it 'comes back on the Sentinel tab after a refusal' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { sentinel: { small:  { mode: 'restrict', groups: [] },
                                  medium: { mode: 'restrict', groups: [staff] } } }

      # Parsed rather than string-matched: HAML orders attributes alphabetically,
      # so asserting on raw HTML couples the test to that ordering.
      pane = response.parsed_body.at_css('#sentinel')
      expect(pane['class']).to include('active')
    end
  end
end
