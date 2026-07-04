# frozen_string_literal: true

require 'rails_helper'

# The restore-a-withdrawal registry. Inherits the Admin::BaseController gate,
# lists tombstoned resources, and reverses a withdrawal via atlas_rb's
# operator-only Admin restorers. TombstonedItems and atlas_rb are stubbed so
# these exercise the Cerberus controller/view wiring + the type dispatch, not
# Atlas or the live Solr inverse query (covered in tombstoned_items_spec).
RSpec.describe 'Admin::Tombstones', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP])
  end

  def tombstoned_doc(noid:, title:, klass: 'Work')
    SolrDocument.new('id'                      => "uuid-#{noid}",
                     'alternate_ids_tesim'     => ["id-#{noid}"],
                     'internal_resource_tesim' => klass,
                     'title_tsim'              => [title],
                     'tombstoned_bsi'          => true)
  end

  def fake_results(*docs)
    instance_double(Blacklight::Solr::Response, documents: docs, total_pages: 1)
  end

  describe 'admin gate' do
    it 'forbids :privileged staff' do
      sign_in staff_user
      get '/admin/tombstones'
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects the unauthenticated to sign in' do
      get '/admin/tombstones'
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'as admin' do
    before { sign_in admin_user }

    describe 'GET index' do
      it 'lists each withdrawn item with its title, PID and a restore action' do
        allow(TombstonedItems).to receive(:call)
          .and_return(fake_results(tombstoned_doc(noid: 'abc', title: 'Withdrawn Thesis'),
                                   tombstoned_doc(noid: 'xyz', title: 'Old Community', klass: 'Community')))

        get '/admin/tombstones'

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Withdrawn Thesis', 'abc', 'Old Community', 'Restore')
      end

      it 'shows the empty state when nothing is tombstoned' do
        allow(TombstonedItems).to receive(:call).and_return(fake_results)
        get '/admin/tombstones'
        expect(response.body).to include('Nothing is tombstoned')
      end
    end

    describe 'POST restore' do
      it 'dispatches to the Work restorer and redirects with a notice' do
        expect(AtlasRb::Admin::Work).to receive(:restore).with('abc').and_return(instance_double(Faraday::Response, success?: true))

        post '/admin/tombstones/abc/restore', params: { type: 'Work' }

        expect(response).to redirect_to(admin_tombstones_path)
        expect(flash[:notice]).to include('live again')
      end

      it 'dispatches to the Community restorer for a Community' do
        expect(AtlasRb::Admin::Community).to receive(:restore).with('xyz').and_return(instance_double(Faraday::Response, success?: true))
        post '/admin/tombstones/xyz/restore', params: { type: 'Community' }
        expect(response).to redirect_to(admin_tombstones_path)
      end

      it 'rejects an unknown resource type without calling atlas_rb' do
        expect(AtlasRb::Admin::Work).not_to receive(:restore)
        post '/admin/tombstones/abc/restore', params: { type: 'Pizza' }
        expect(flash[:alert]).to include('Unknown resource type')
      end

      it 'reports a failure when Atlas refuses (e.g. a withdrawn parent)' do
        allow(AtlasRb::Admin::Collection).to receive(:restore).and_return(instance_double(Faraday::Response, success?: false))
        post '/admin/tombstones/abc/restore', params: { type: 'Collection' }
        expect(flash[:alert]).to include('tombstoned parent')
      end
    end
  end
end
