# frozen_string_literal: true

require 'rails_helper'

# The Set edit page's two bulk actions. Runs against the real test Atlas like the
# other Set specs: a real Compilation is created, so the curator gate and the
# Set load are exercised end to end. The sweeps themselves are specced at the job
# level; this file covers the HTTP surface — who is offered the tabs, who may
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
    allow(SetPrivatizeJob).to receive(:perform_later)
    allow(SetSentinelApplyJob).to receive(:perform_later)
  end

  describe 'who is offered the tabs' do
    it 'shows both bulk tabs to a full admin' do
      sign_in admin
      get "/sets/#{set['id']}/edit"

      expect(response.body).to include('derivative-access-tab', 'visibility-tab')
    end

    it 'shows both bulk tabs to the devolved tier' do
      sign_in devolved
      get "/sets/#{set['id']}/edit"

      expect(response.body).to include('derivative-access-tab', 'visibility-tab')
    end

    it 'shows neither to a curator who merely owns the set' do
      sign_in owner
      get "/sets/#{set['id']}/edit"

      expect(response.body).not_to include('derivative-access-tab')
      expect(response.body).not_to include('visibility-tab')
    end
  end

  describe 'the write gate' do
    it 'refuses privatize to a non-operator' do
      sign_in owner
      post "/sets/#{set['id']}/privatize"

      expect(response).to have_http_status(:forbidden)
      expect(SetPrivatizeJob).not_to have_received(:perform_later)
    end

    it 'refuses apply to a non-operator' do
      sign_in owner
      post "/sets/#{set['id']}/apply_sentinel"

      expect(response).to have_http_status(:forbidden)
      expect(SetSentinelApplyJob).not_to have_received(:perform_later)
    end

    it 'refuses the policy write to a non-operator' do
      sign_in owner
      patch "/sets/#{set['id']}/sentinel", params: { sentinel: { master: { mode: 'restrict', groups: [staff] } } }

      expect(response).to have_http_status(:forbidden)
      expect(Sentinel.find_by(target_id: set['id'])).to be_nil
    end

    it 'redirects an anonymous visitor to sign in' do
      post "/sets/#{set['id']}/privatize"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'privatize' do
    it 'enqueues the sweep and says so' do
      sign_in admin
      post "/sets/#{set['id']}/privatize"

      expect(SetPrivatizeJob).to have_received(:perform_later).with(set_noid: set['id'])
      expect(response).to redirect_to(edit_set_path(set['id'], anchor: 'visibility'))
      expect(flash[:notice]).to include('Making this set’s works private')
    end
  end

  describe 'applying the policy' do
    it 'refuses to sweep when no policy has been saved' do
      sign_in admin
      post "/sets/#{set['id']}/apply_sentinel"

      expect(SetSentinelApplyJob).not_to have_received(:perform_later)
      expect(flash[:alert]).to include('Save a derivative access policy')
    end

    it 'enqueues the sweep once a policy exists' do
      Sentinel.create!(target_id: set['id'], policy: { 'master' => [staff] })
      sign_in admin
      post "/sets/#{set['id']}/apply_sentinel"

      expect(SetSentinelApplyJob).to have_received(:perform_later).with(set_noid: set['id'])
      expect(response).to redirect_to(edit_set_path(set['id'], anchor: 'derivative-access'))
    end
  end

  describe 'authoring the policy' do
    it 'saves a restricted tier' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel", params: { sentinel: { master: { mode: 'restrict', groups: [staff] } } }

      expect(Sentinel.find_by(target_id: set['id']).policy).to eq({ 'master' => [staff] })
      expect(response).to redirect_to(edit_set_path(set['id'], anchor: 'derivative-access'))
    end

    # A Set is not a container, so an unrestricted tier is omitted rather than
    # written as ['public'] — an omitted tier rides each Work at apply time,
    # which is the only thing that works across a Set of mixed visibility.
    it 'omits an unrestricted tier instead of claiming public' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { sentinel: { small: { mode: 'public' }, master: { mode: 'restrict', groups: [staff] } } }

      expect(Sentinel.find_by(target_id: set['id']).policy).to eq({ 'master' => [staff] })
    end

    it 'refuses a policy that widens as resolution grows, and re-renders the ladder' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { sentinel: { small:  { mode: 'restrict', groups: [] },
                                  master: { mode: 'restrict', groups: [staff] } } }

      # Monotonicity is a property of the ladder, so it still applies without a
      # container: master must not be more open than small.
      expect(response).to have_http_status(:unprocessable_content)
      expect(Sentinel.find_by(target_id: set['id'])).to be_nil
    end

    it 'comes back on the derivative-access tab after a refusal' do
      sign_in admin
      patch "/sets/#{set['id']}/sentinel",
            params: { sentinel: { small:  { mode: 'restrict', groups: [] },
                                  medium: { mode: 'restrict', groups: [staff] } } }

      # Parsed rather than string-matched: HAML orders attributes alphabetically,
      # so asserting on raw HTML couples the test to that ordering.
      pane = response.parsed_body.at_css('#derivative-access')
      expect(pane['class']).to include('active')
    end
  end
end
