# frozen_string_literal: true

require 'rails_helper'

# The Collection edit page's "Derivative access" tab writes a Sentinel — the
# per-tier derivative-permission default applied to Works added under the
# collection. Runs against the live Atlas test backend like the other
# resource-controller specs: a real Collection is created and edit granted to the
# staff group, so the authorize_resource_writes! :edit gate is exercised
# end-to-end (the Sentinel itself is a Cerberus-DB row).
RSpec.describe 'Collections sentinel', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:fixtures)   { '/home/cerberus/web/spec/fixtures/files' }
  let(:community)  { AtlasRb::Community.create(nil, "#{fixtures}/community-mods.xml", nuid: '000000004') }
  let(:collection) { AtlasRb::Collection.create(community.id, "#{fixtures}/collection-mods.xml", nuid: '000000004') }

  let(:editor) do
    User.new(email: 'editor@example.com', password: 'password', nuid: '000000002',
             name: 'Ed, Itor', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  let(:outsider) do
    User.new(email: 'outsider@example.com', password: 'password',
             name: 'Out, Sider', role: 'standard', groups: ['randos'])
  end

  def grant_edit!
    AtlasRb::Collection.metadata(collection.id, { 'permissions' => { 'edit' => [Permissions::STAFF_EDIT_GROUP] } },
                                 nuid: '000000004')
  end

  # Small/medium public, large/service reserved to the staff group — a valid
  # monotonic policy (audience narrows as resolution grows).
  let(:valid_params) do
    { sentinel: { small: { mode: 'public' }, medium: { mode: 'public' },
                  large: { mode: 'restrict', groups: [Permissions::STAFF_EDIT_GROUP] },
                  service: { mode: 'restrict', groups: [Permissions::STAFF_EDIT_GROUP] } } }
  end

  before { grant_edit! }

  describe 'authorization' do
    it 'forbids the unauthenticated and writes nothing' do
      expect { patch sentinel_collection_path(collection.id), params: valid_params }
        .not_to change(Sentinel, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids an authenticated non-editor and writes nothing' do
      sign_in outsider
      expect { patch sentinel_collection_path(collection.id), params: valid_params }
        .not_to change(Sentinel, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'as an in-group editor' do
    before { sign_in editor }

    it 'creates the collection Sentinel from the per-tier form' do
      expect { patch sentinel_collection_path(collection.id), params: valid_params }
        .to change(Sentinel, :count).by(1)

      expect(Sentinel.find_by(target_id: collection.id).policy).to eq(
        'small' => ['public'], 'medium' => ['public'],
        'large' => [Permissions::STAFF_EDIT_GROUP], 'service' => [Permissions::STAFF_EDIT_GROUP]
      )
      expect(response).to redirect_to(edit_collection_path(collection.id, anchor: 'derivative-access'))
      expect(flash[:notice]).to eq('Derivative access default saved.')
    end

    it 'upserts an existing Sentinel rather than duplicating it' do
      Sentinel.create!(target_id: collection.id, policy: { 'small' => ['public'] })

      expect { patch sentinel_collection_path(collection.id), params: valid_params }
        .not_to change(Sentinel, :count)
      expect(Sentinel.find_by(target_id: collection.id).policy['large']).to eq([Permissions::STAFF_EDIT_GROUP])
    end

    it 'authors the wider vocabulary — master plus independent media' do
      params = { sentinel: { small:  { mode: 'public' },
                             master: { mode: 'restrict', groups: [Permissions::STAFF_EDIT_GROUP] },
                             pdf:    { mode: 'restrict', groups: [Permissions::STAFF_EDIT_GROUP] },
                             audio:  { mode: 'public' } } }

      patch sentinel_collection_path(collection.id), params: params

      expect(Sentinel.find_by(target_id: collection.id).policy).to eq(
        'small' => ['public'], 'master' => [Permissions::STAFF_EDIT_GROUP],
        'pdf' => [Permissions::STAFF_EDIT_GROUP], 'audio' => ['public']
      )
    end

    it 'refuses an incoherent (non-monotonic) policy and flashes the error' do
      bad = { sentinel: { small: { mode: 'restrict', groups: [Permissions::STAFF_EDIT_GROUP] },
                          medium: { mode: 'public' }, large: { mode: 'public' }, service: { mode: 'public' } } }

      expect { patch sentinel_collection_path(collection.id), params: bad }
        .not_to change(Sentinel, :count)
      expect(flash[:alert]).to be_present
    end
  end
end
