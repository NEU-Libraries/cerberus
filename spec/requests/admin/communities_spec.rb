# frozen_string_literal: true

require 'rails_helper'

# The admin communities registry. The Solr read is stubbed; gating of the
# search itself is the SearchBuilder's and covered there.
RSpec.describe 'Admin::Communities', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) { User.new(email: 'admin@example.com', nuid: '000000004', name: 'User, Admin', role: 'admin') }
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, Permissions::ADMIN_GROUP])
  end
  let(:doc) do
    SolrDocument.new('id' => 'uuid-eng', 'alternate_ids_tesim' => ['id-eng1234'], 'title_tsim' => ['College of Engineering'],
                     'internal_resource_tesim' => ['Community'])
  end
  let(:search_response) do
    instance_double(Blacklight::Solr::Response, documents: [doc], total: 1, total_pages: 1)
  end

  before do
    allow(Blacklight.default_index).to receive(:search).and_return(search_response)
    allow(StructuralParents).to receive(:call).and_return({})
  end

  it 'lists every community to an admin, with Edit and People' do
    sign_in admin_user

    get admin_communities_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('College of Engineering', 'eng1234', '1 community',
                                     edit_community_path('eng1234'), CGI.escapeHTML(edit_community_path('eng1234', tab: 'people')))
  end

  # The People tab is admin-only, so its link is too.
  it 'lists them to a delegated admin without the People link' do
    sign_in delegate_user

    get admin_communities_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_community_path('eng1234'))
    expect(response.body).not_to include('tab=people')
  end

  it 'sorts by title when browsing and by relevance when searching' do
    sign_in admin_user

    get admin_communities_path
    expect(Blacklight.default_index).to have_received(:search)
      .with(params: satisfy { |builder| builder.to_hash[:sort] == 'title_ssi asc' })

    get admin_communities_path(q: 'engineering')
    expect(Blacklight.default_index).to have_received(:search)
      .with(params: satisfy { |builder| builder.to_hash[:sort] != 'title_ssi asc' })
  end

  it 'refuses privileged staff without the admin group' do
    sign_in User.new(email: 's@example.com', nuid: '000000006', role: 'privileged',
                     groups: [Permissions::STAFF_EDIT_GROUP])

    get admin_communities_path

    expect(response).to have_http_status(:forbidden)
  end
end
