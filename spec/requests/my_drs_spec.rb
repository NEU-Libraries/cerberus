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
      # No workspace means no Deposit control, so the empty state must not ask for one.
      expect(response.body).to include('Your account has no workspace to deposit into.')
      expect(response.body).not_to include('Deposit a file to start your workspace.')
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

    # An unfinished deposit is hidden from general discovery, so My DRS is the only
    # place its depositor can find one — and they are the only person who can
    # finish it.
    it 'lists this depositor\'s unfinished deposits with a route that finishes one' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      unfinished = SolrDocument.new('id' => 'uuid-u', 'title_tsim' => ['thesis.docx'],
                                    'alternate_ids_tesim' => ['id-unoid'], 'in_progress_bsi' => true)
      allow_any_instance_of(MyDrsController).to receive(:unfinished_deposits).and_return([unfinished])

      get '/my_drs'

      expect(response.body).to include('Deposits to finish')
      expect(response.body).to include('thesis.docx')
      expect(response.body).to include(metadata_work_path('unoid'))
      expect(response.body).to include(tombstone_work_path('unoid', return_to: my_drs_path))
    end

    it 'omits the panel entirely when nothing is unfinished' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      allow_any_instance_of(MyDrsController).to receive(:unfinished_deposits).and_return([])

      get '/my_drs'

      expect(response.body).not_to include('Deposits to finish')
    end

    # A depositor cannot re-run an enrichment job, so this panel exists to tell
    # them what is missing rather than to offer an action — otherwise a missing
    # thumbnail just reads as how DRS looks.
    it 'lists their works a job gave up on, and says what each is missing' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      flagged = SolrDocument.new('id' => 'uuid-i', 'title_tsim' => ['thesis.docx'],
                                 'alternate_ids_tesim' => ['id-inoid'], 'incomplete_bsi' => true,
                                 'incomplete_reason_ssi' => IncompleteReasons::PDF_RENDITION)
      allow_any_instance_of(MyDrsController).to receive(:incomplete_works).and_return([flagged])

      get '/my_drs'

      expect(response.body).to include('Works with something missing')
      expect(response.body).to include('No PDF version was made')
      expect(response.body).to include(work_path('inoid'))
    end

    it 'omits that panel when nothing is flagged' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      allow_any_instance_of(MyDrsController).to receive(:incomplete_works).and_return([])

      get '/my_drs'

      expect(response.body).not_to include('Works with something missing')
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

    # Librarians troubleshoot from this card, so a one-account person gets it
    # too: the email and the group names, with nothing to switch or prefer.
    it 'shows a single-account person their email and groups, without switch controls' do
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      allow(AtlasRb::User).to receive(:accounts).and_return(
        AtlasRb::Mash.new('nuid' => '000000004', 'accounts' => [
                            { 'email' => user.email, 'affiliation' => 'staff', 'role' => 'standard',
                              'groups' => %w[g:alpha g:beta], 'preferred' => true }
                          ])
      )

      get '/my_drs'

      expect(response.body).to include('Your accounts', user.email, 'the groups it belongs to')
      expect(Capybara.string(response.body)).to have_css('.account-diff__chip', count: 2)
      expect(response.body).not_to include('Switch to this account', 'Set as default', 'Preferred')
    end
  end

  # An admin debugging a depositor's problem must see the depositor's My DRS,
  # but nothing on it that acts on the admin's own session or credentials.
  context 'while an admin acts as the depositor' do
    let(:admin) do
      User.new(email: 'admin@example.com', password: 'password',
               nuid: '000000009', role: 'admin', groups: [Permissions::API_GROUP])
    end
    let(:target_groups) { [Permissions::API_GROUP] }

    before do
      allow(AtlasRb::AuditEvent).to receive(:emit)
      allow(AtlasRb::Authentication).to receive(:login).with(user.nuid).and_return(
        AtlasRb::Mash.new('nuid' => user.nuid, 'name' => 'Depositor, Dee', 'email' => user.email,
                          'role' => user.role, 'groups' => target_groups)
      )
      allow(AtlasRb::Person).to receive(:resolve).and_return([])
      allow(AtlasRb::User).to receive(:accounts).and_return(
        AtlasRb::Mash.new('nuid' => user.nuid, 'accounts' => [
                            { 'email' => user.email, 'affiliation' => 'staff', 'role' => 'standard',
                              'groups' => [], 'preferred' => true },
                            { 'email' => 'depositor@husky.neu.edu', 'affiliation' => 'student',
                              'role' => 'standard', 'groups' => [], 'preferred' => false }
                          ])
      )
      sign_in admin
      post admin_act_as_path, params: { nuid: user.nuid }
    end

    it "looks up the target's Person and accounts, with the admin as the caller" do
      get '/my_drs'

      expect(response).to have_http_status(:ok)
      expect(AtlasRb::Person).to have_received(:resolve).with([user.nuid])
      expect(AtlasRb::User).to have_received(:accounts).with(user.nuid, nuid: admin.nuid)
    end

    it 'marks the target\'s account current and hides switching and the API token card' do
      get '/my_drs'

      page = Capybara.string(response.body)
      expect(page.find('.account-row', text: user.email)).to have_css('.badge', text: 'Current')
      expect(response.body).not_to include('Switch to this account', 'Set as default')
      expect(page).to have_no_css('.my-drs-card--api')
    end
  end
end
