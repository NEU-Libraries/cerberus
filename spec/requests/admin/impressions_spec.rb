# frozen_string_literal: true

require 'rails_helper'

# Mirrors spec/requests/admin/dashboard_spec.rb: the surface is devolved —
# :admin and the devolved-admin tier (User#admin_delegate?) both pass;
# :privileged staff without the admin group gets 403, and the unauthenticated
# are redirected to sign-in. Purely local reads (ImpressionsReport,
# Cerberus's own TimescaleDB rollups), so no Atlas dependency either way.
RSpec.describe 'Admin::Impressions', type: :request do
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
  # :privileged + the admin group jointly — the devolved-admin tier (stock
  # pilot user 000000002). Usage analytics is one of the five devolved surfaces.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  describe 'authorization gate' do
    it 'renders the dashboard for an admin' do
      sign_in admin_user
      get '/admin/impressions'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Usage analytics')
    end

    it 'renders the dashboard for a devolved-admin delegate' do
      sign_in delegate_user
      get '/admin/impressions'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Usage analytics')
    end

    it 'forbids :privileged staff without the admin group with 403' do
      sign_in staff_user
      get '/admin/impressions'

      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects the unauthenticated to sign-in' do
      get '/admin/impressions'

      expect(response).to have_http_status(:found)
    end
  end

  describe 'export' do
    before { sign_in admin_user }

    it 'streams CSV' do
      get '/admin/impressions/export.csv'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/csv')
    end

    it 'streams Excel' do
      get '/admin/impressions/export.xlsx'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    it 'names a scoped download after the table it came from' do
      get '/admin/impressions/export.csv?kind=container'

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('impressions-collections-')
    end

    it 'leaves an unscoped download named as it was' do
      get '/admin/impressions/export.csv'

      expect(response.headers['Content-Disposition']).to match(/impressions-\d{4}-/)
    end
  end

  describe 'item picker' do
    before { sign_in admin_user }

    def container_doc(noid:, title:, klass: 'Collection')
      SolrDocument.new('id'                      => "uuid-#{noid}",
                       'alternate_ids_tesim'     => ["id-#{noid}"],
                       'internal_resource_tesim' => klass,
                       'title_tsim'              => [title])
    end

    it 'shows matching results for a search query' do
      allow(ResourceSearch).to receive(:call)
        .and_return(instance_double(Blacklight::Solr::Response, documents: [container_doc(noid: 'w1', title: 'Sample Work', klass: 'Work')]))

      get '/admin/impressions', params: { q: 'Sample' }

      expect(response.body).to include('Sample Work', 'Scope')
    end

    it 'scopes the dashboard to a picked Work and shows the chip' do
      get '/admin/impressions', params: { item_noid: 'w1', item_uuid: 'uuid-w1', item_klass: 'Work', item_title: 'Sample Work' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Scoped to: Work: Sample Work')
      expect(response.body).not_to include('Top collections')
    end

    it 'scopes to a picked Collection and keeps the Top collections tab' do
      allow(ContainerDescendantsQuery).to receive(:new).with(noid: 'c1', uuid: 'uuid-c1')
                                                       .and_return(instance_double(ContainerDescendantsQuery, noids: ['c1'], work_noids: [], container_noids: ['c1']))

      get '/admin/impressions', params: { item_noid: 'c1', item_uuid: 'uuid-c1', item_klass: 'Collection', item_title: 'Sample Collection' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Scoped to: Collection: Sample Collection')
      expect(response.body).to include('Top collections')
    end
  end

  describe 'facet picker' do
    before { sign_in admin_user }

    it 'facets by Content type via the canonical params and hides Top collections' do
      allow(FacetedWorkNoids).to receive(:call).with(type: 'content', value: 'Image').and_return([])

      get '/admin/impressions', params: { facet_type: 'content', facet_value: 'Image' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Faceted by: Content: Image')
      expect(response.body).not_to include('Top collections')
    end

    it 'facets by Featured Content via the packed select param' do
      allow(FacetedWorkNoids).to receive(:call).with(type: 'featured', value: 'Datasets').and_return([])

      get '/admin/impressions', params: { facet: 'featured::Datasets' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Faceted by: Featured Content: Datasets')
    end

    it 'combines an item scope with a facet, hiding Top collections even for a Collection' do
      allow(ContainerDescendantsQuery).to receive(:new).with(noid: 'c1', uuid: 'uuid-c1')
                                                       .and_return(instance_double(ContainerDescendantsQuery, noids: ['c1'], work_noids: [], container_noids: ['c1']))
      allow(FacetedWorkNoids).to receive(:call).with(type: 'content', value: 'Image').and_return([])

      get '/admin/impressions', params: { item_noid: 'c1', item_uuid: 'uuid-c1', item_klass: 'Collection',
                                          item_title: 'Sample Collection', facet_type: 'content', facet_value: 'Image' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Scoped to: Collection: Sample Collection', 'Faceted by: Content: Image')
      expect(response.body).not_to include('Top collections')
    end
  end

  describe 'Composition tab' do
    before { sign_in admin_user }

    it 'always renders, ignoring the date range/segment/scope, with entity counts and a classification chart' do
      allow(SolrFacetValues).to receive(:call).with(field: 'internal_resource_tesim', extra_fq: [])
                                              .and_return([['community', 5], ['collection', 10], ['work', 200], ['person', 8]])
      allow(Blacklight.default_index).to receive(:search)
        .with(hash_including(fq: ['internal_resource_tesim:Work', 'read_access_group_ssim:public']))
        .and_return(instance_double(Blacklight::Solr::Response, total: 150))
      allow(SolrFacetValues).to receive(:call).with(field: 'classification_ssim', extra_fq: ['internal_resource_tesim:Work'])
                                              .and_return([['Image', 90], ['Text', 60]])

      get '/admin/impressions', params: { segment: 'all', item_noid: 'w1', item_uuid: 'uuid-w1', item_klass: 'Work', item_title: 'X' }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Composition', 'Faculty', 'Staff', 'Public works', 'Private works')
    end
  end
end
