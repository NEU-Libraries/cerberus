# frozen_string_literal: true

require 'rails_helper'

# On-demand Solr re-projection for one Work (inline) and one Set (queued).
#
# The gate matters more here than on most admin surfaces: the Atlas endpoint
# behind both actions runs on the system token and applies no per-user check,
# so this controller's before_action is the only authorization there is. The
# matrix below is the real subject of this file. atlas_rb is stubbed
# throughout — these exercise Cerberus wiring, not Atlas.
RSpec.describe 'Admin::Reindex', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  # :privileged, but not in the admin group — the negative control that role
  # alone is not sufficient for the devolved tier.
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  # :privileged + the admin group jointly — the devolved-admin tier.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  let(:compilation) { AtlasRb::Mash.new('id' => 'set123', 'title' => 'Reading list') }

  def stub_reindex(status: 204)
    allow(AtlasRb::System).to receive(:reindex).and_return(instance_double(Faraday::Response, status: status))
  end

  describe 'the gate' do
    context 'as :privileged staff without the admin group' do
      before { sign_in staff_user }

      it 'forbids both actions before reaching Atlas' do
        allow(AtlasRb::System).to receive(:reindex)
        allow(SetReindexJob).to receive(:perform_later)

        post '/admin/reindex/work/abc1234'
        expect(response).to have_http_status(:forbidden)
        post '/admin/reindex/set/set123'
        expect(response).to have_http_status(:forbidden)

        expect(AtlasRb::System).not_to have_received(:reindex)
        expect(SetReindexJob).not_to have_received(:perform_later)
      end
    end

    context 'unauthenticated' do
      it 'redirects to sign-in' do
        post '/admin/reindex/work/abc1234'
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'as the devolved-admin tier' do
      before { sign_in delegate_user }

      it 'allows the work action' do
        stub_reindex
        post '/admin/reindex/work/abc1234'
        expect(response).to redirect_to(work_path('abc1234'))
      end

      it 'allows the set action' do
        allow(AtlasRb::Compilation).to receive(:find).and_return(compilation)
        allow(SetReindexJob).to receive(:perform_later)

        post '/admin/reindex/set/set123'

        expect(response).to redirect_to(set_path('set123'))
      end
    end
  end

  describe 'POST /admin/reindex/work/:noid' do
    before { sign_in admin_user }

    it 'reindexes the work and says so' do
      stub_reindex
      post '/admin/reindex/work/abc1234'

      expect(AtlasRb::System).to have_received(:reindex).with('abc1234')
      expect(flash[:notice]).to eq('Work reindexed.')
    end

    it 'reports an unknown noid rather than claiming success' do
      stub_reindex(status: 404)
      post '/admin/reindex/work/nope'

      expect(flash[:alert]).to include('No resource found')
      expect(flash[:notice]).to be_nil
    end

    it 'reports a transport failure instead of raising' do
      allow(AtlasRb::System).to receive(:reindex).and_raise(Faraday::ConnectionFailed, 'refused')

      post '/admin/reindex/work/abc1234'

      expect(response).to redirect_to(work_path('abc1234'))
      expect(flash[:alert]).to include('failed')
    end
  end

  describe 'POST /admin/reindex/set/:noid' do
    before { sign_in admin_user }

    it 'queues the job rather than walking the recipe in the request' do
      allow(AtlasRb::Compilation).to receive(:find).with('set123').and_return(compilation)
      allow(SetReindexJob).to receive(:perform_later)

      post '/admin/reindex/set/set123'

      expect(SetReindexJob).to have_received(:perform_later).with('set123')
      expect(flash[:notice]).to include('Reading list')
    end

    # The set is read first so a bad id fails in front of the person who
    # clicked, not inside a job nobody is watching.
    it '404s an unknown set without queueing anything' do
      allow(AtlasRb::Compilation).to receive(:find).and_return(nil)
      allow(SetReindexJob).to receive(:perform_later)

      post '/admin/reindex/set/nope'

      expect(response).to have_http_status(:not_found)
      expect(SetReindexJob).not_to have_received(:perform_later)
    end

    it 'forbids a set Atlas will not show the caller' do
      allow(AtlasRb::Compilation).to receive(:find).and_raise(AtlasRb::ForbiddenError.new('forbidden'))
      allow(SetReindexJob).to receive(:perform_later)

      post '/admin/reindex/set/private1'

      expect(response).to have_http_status(:forbidden)
      expect(SetReindexJob).not_to have_received(:perform_later)
    end
  end
end
