# frozen_string_literal: true

require 'rails_helper'

# My DRS is the depositor's two-space home: their own Collections (workspace,
# an ungated owned-by-me Solr search) beside the works they've published into
# community showcases (grouped by category, via the linked-member edge). The
# empty render runs against real test Solr/Atlas; the populated grouping stubs
# the per-showcase queries so the category fan-out and ordering are exercised
# without depending on seeded published works (which need the Atlas personal
# root that hasn't shipped yet).
RSpec.describe 'My DRS', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) do
    User.new(email: 'depositor@example.com', password: 'password',
             nuid: '000000004', role: 'standard', groups: [])
  end

  it 'redirects an anonymous visitor away' do
    get '/my_drs'
    expect(response).to redirect_to(root_path)
  end

  context 'signed in' do
    before do
      sign_in user
      # My DRS now consults the accounts list; default to a single account so the
      # switcher panel is absent (the panel spec below overrides this), keeping
      # these renders off the live accounts call.
      allow(AtlasRb::User).to receive(:accounts).and_return(
        AtlasRb::Mash.new('nuid' => '000000004', 'accounts' => [])
      )
    end

    it 'renders both spaces, empty, for a depositor with no Person or collections' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])

      get '/my_drs'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('My DRS')
      expect(response.body).to include('My workspace')
      expect(response.body).to include('Published to my community')
      # Column-level empty states.
      expect(response.body).to include('Nothing published yet')
    end

    it 'lists owned collections and groups published works by showcase category' do
      person = AtlasRb::Mash.new('nuid' => '000000004', 'personal_root_id' => 'root1',
                                 'affiliated_community_ids' => ['comm1'])
      allow(AtlasRb::Person).to receive(:resolve).and_return([person])

      collection = SolrDocument.new('id' => 'uuid-c', 'title_tsim' => ['My Working Files'],
                                    'alternate_ids_tesim' => ['id-cnoid'])
      showcase   = SolrDocument.new('id' => 'uuid-ds', 'title_tsim' => ['Datasets'],
                                    'alternate_ids_tesim' => ['id-dsnoid'], 'featured_bsi' => true)
      work       = SolrDocument.new('id' => 'uuid-w', 'title_tsim' => ['My Dataset'],
                                    'alternate_ids_tesim' => ['id-wnoid'])

      allow_any_instance_of(MyDrsController).to receive(:workspace_collections).and_return([collection])
      allow_any_instance_of(MyDrsController).to receive(:showcase_docs).and_return([showcase])
      allow_any_instance_of(MyDrsController).to receive(:works_published_into).with('uuid-ds').and_return([work])

      get '/my_drs'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('My Working Files') # workspace collection
      expect(response.body).to include('Datasets')         # showcase category heading
      expect(response.body).to include('My Dataset')       # published work under it
    end

    it 'renders the accounts switcher for a person with more than one account' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      allow(AtlasRb::User).to receive(:accounts).and_return(
        AtlasRb::Mash.new('nuid' => '000000004', 'accounts' => [
                            { 'email' => 'depositor@example.com', 'affiliation' => 'staff',
                              'role' => 'standard', 'groups' => %w[g:shared g:staff], 'preferred' => true },
                            { 'email' => 'depositor@husky.neu.edu', 'affiliation' => 'student',
                              'role' => 'standard', 'groups' => %w[g:shared g:student], 'preferred' => false }
                          ])
      )

      get '/my_drs'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Your accounts')
      expect(response.body).to include('depositor@husky.neu.edu')
      expect(response.body).to include('Switch to this account')
    end
  end
end
