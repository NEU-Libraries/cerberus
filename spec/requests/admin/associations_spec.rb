# frozen_string_literal: true

require 'rails_helper'

# Admin associated-works surface: find a Work → manage the typed edges between
# it and other Works (add / remove). atlas_rb and the resource search are
# stubbed; these exercise the Cerberus controller/view wiring and the direction
# handling, not Atlas. The gated resolution the *public* box does is covered in
# work_associations_spec, against real fixtures.
RSpec.describe 'Admin::Associations', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end
  # :privileged, but not in the admin group.
  let(:staff_user) do
    User.new(email: 'staff@example.com', password: 'password',
             nuid: '000000006', name: 'Williams, Susan', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end
  # :privileged + the admin group jointly — the devolved-admin tier. Atlas
  # grants that tier the association write, but this surface stays :admin-only,
  # matching the other finder surfaces it sits beside.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  def doc(noid:, title:, klass: 'Work')
    SolrDocument.new('id'                      => "uuid-#{noid}",
                     'alternate_ids_tesim'     => ["id-#{noid}"],
                     'internal_resource_tesim' => klass,
                     'title_tsim'              => [title])
  end

  def fake_results(*docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  def work_resource(noid:, title: 'Ocean survey codebook')
    OpenStruct.new(klass:    'Work',
                   resource: OpenStruct.new(id: noid, title: title, valkyrie_id: "uuid-#{noid}"))
  end

  def stub_manage(edges)
    allow(AtlasRb::Resource).to receive(:find).and_return(work_resource(noid: 'codebook'))
    allow(AtlasRb::Work).to receive(:associations).and_return(edges)
    allow(AtlasRb::Resource).to receive(:find_many)
      .and_return([OpenStruct.new('noid' => 'dataset', :title => 'Ocean survey data')])
  end

  describe 'admin gate' do
    it 'forbids :privileged staff every action' do
      sign_in staff_user
      get '/admin/associations'
      expect(response).to have_http_status(:forbidden)
      post '/admin/associations/add', params: { work_id: 'a', target_id: 'b', type: 'is_codebook_for' }
      expect(response).to have_http_status(:forbidden)
    end

    # Atlas would accept the write from this tier; Cerberus does not offer it
    # here, so the refusal is Cerberus's own and must be asserted as such.
    it 'forbids the devolved-admin delegate' do
      sign_in delegate_user
      expect(AtlasRb::Work).not_to receive(:associate)
      post '/admin/associations/add', params: { work_id: 'a', target_id: 'b', type: 'is_codebook_for' }
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects the unauthenticated to sign in' do
      get '/admin/associations'
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe 'as admin' do
    before { sign_in admin_user }

    describe 'GET index' do
      it 'renders the finder without searching on an empty query' do
        expect(ResourceSearch).not_to receive(:call)
        get '/admin/associations'
        expect(response.body).to include('Associated works')
      end

      it 'searches Works only' do
        expect(ResourceSearch).to receive(:call)
          .with(hash_including(types: %w[Work])).and_return(fake_results(doc(noid: 'abc', title: 'A Codebook')))
        get '/admin/associations', params: { q: 'codebook' }
        expect(response.body).to include('A Codebook')
      end
    end

    describe 'GET manage' do
      it 'lists an outbound edge under its predicate' do
        stub_manage('outbound' => { 'is_codebook_for' => ['dataset'] }, 'inbound' => {})

        get '/admin/associations/manage', params: { work_id: 'codebook' }

        expect(response.body).to include('Is codebook for', 'Ocean survey data', 'dataset')
      end

      it 'lists an inbound edge under its own phrasing' do
        stub_manage('outbound' => {}, 'inbound' => { 'is_codebook_for' => ['dataset'] })

        get '/admin/associations/manage', params: { work_id: 'codebook' }

        expect(response.body).to include('Codebooks')
      end

      it 'says so in both directions when there is nothing' do
        stub_manage('outbound' => {}, 'inbound' => {})

        get '/admin/associations/manage', params: { work_id: 'codebook' }

        expect(response.body).to include('This work claims no relationship to another',
                                         'No other work claims a relationship to this one')
      end

      # Pre-empts Atlas's self_association rejection at the point of choice
      # rather than after the write.
      it 'keeps the managed Work out of its own candidate list' do
        stub_manage('outbound' => {}, 'inbound' => {})
        expect(ResourceSearch).to receive(:call)
          .with(hash_including(exclude_node_uuid: 'uuid-codebook')).and_return(fake_results)

        get '/admin/associations/manage', params: { work_id: 'codebook', q: 'ocean' }
      end
    end

    describe 'POST add' do
      it 'asserts the edge outward from the managed Work' do
        expect(AtlasRb::Work).to receive(:associate)
          .with('codebook', 'dataset', type: 'is_codebook_for')

        post '/admin/associations/add', params: { work_id: 'codebook', target_id: 'dataset',
                                                  type: 'is_codebook_for' }

        expect(response).to redirect_to(admin_associations_manage_path(work_id: 'codebook'))
        expect(flash[:notice]).to include('Association added')
      end

      it 'names the reason when Atlas refuses' do
        allow(AtlasRb::Work).to receive(:associate)
          .and_raise(AtlasRb::WorkAssociationError.new('nope', code: 'tombstoned_target'))

        post '/admin/associations/add', params: { work_id: 'codebook', target_id: 'dataset',
                                                  type: 'is_codebook_for' }

        expect(flash[:alert]).to include('That Work is withdrawn')
      end

      # A code Cerberus has no phrase for must still say something true.
      it 'falls back to the generic refusal on an unknown code' do
        allow(AtlasRb::Work).to receive(:associate)
          .and_raise(AtlasRb::WorkAssociationError.new('nope', code: 'some_new_code'))

        post '/admin/associations/add', params: { work_id: 'codebook', target_id: 'dataset',
                                                  type: 'is_codebook_for' }

        expect(flash[:alert]).to eq(Admin::AssociationsController::GENERIC_REFUSAL)
      end

      it 'reports a transport failure instead of raising' do
        allow(AtlasRb::Work).to receive(:associate).and_raise(Faraday::ConnectionFailed, 'down')

        post '/admin/associations/add', params: { work_id: 'codebook', target_id: 'dataset',
                                                  type: 'is_codebook_for' }

        expect(flash[:alert]).to eq(Admin::AssociationsController::GENERIC_REFUSAL)
      end
    end

    describe 'DELETE remove' do
      # The edge is stored on the asserting Work, so retracting an outbound edge
      # acts on the managed Work.
      it 'retracts an outbound edge from the managed Work' do
        expect(AtlasRb::Work).to receive(:disassociate)
          .with('codebook', 'dataset', type: 'is_codebook_for')

        delete '/admin/associations/remove', params: { work_id: 'codebook', holder_id: 'codebook',
                                                       target_id: 'dataset', type: 'is_codebook_for' }

        expect(response).to redirect_to(admin_associations_manage_path(work_id: 'codebook'))
        expect(flash[:notice]).to include('Association removed')
      end

      # An inbound edge lives on the *other* Work, so the call must name that
      # Work as the holder while the redirect stays on the one being managed.
      # Passing work_id as the holder would silently retract nothing.
      it 'retracts an inbound edge from the Work that asserted it' do
        expect(AtlasRb::Work).to receive(:disassociate)
          .with('other', 'codebook', type: 'is_figure_for')

        delete '/admin/associations/remove', params: { work_id: 'codebook', holder_id: 'other',
                                                       target_id: 'codebook', type: 'is_figure_for' }

        expect(response).to redirect_to(admin_associations_manage_path(work_id: 'codebook'))
      end
    end
  end
end
