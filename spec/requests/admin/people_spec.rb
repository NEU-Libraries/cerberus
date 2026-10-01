# frozen_string_literal: true

require 'rails_helper'

# Admin People registry: create Person records by NUID, edit display_name / bio
# / orcid, and add/remove community affiliations. atlas_rb and the community
# search are stubbed — these exercise the Cerberus controller/view wiring (and
# the admin gate), not Atlas or Solr.
#
# The create and update examples submit every field the form submits, not just
# the one under assertion. The controller splats its permitted params into an
# atlas_rb keyword signature, and verify_partial_doubles checks a stubbed call
# against the real signature — so a permitted key the gem has dropped fails here
# only if the request actually carries it.
RSpec.describe 'Admin::People', type: :request do
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
  # :privileged + the admin group jointly — the devolved-admin tier (stock
  # pilot user 000000002). Manage people is NOT one of the five devolved
  # surfaces; stays :admin-only.
  let(:delegate_user) do
    User.new(email: 'delegate@example.com', password: 'password',
             nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: ['northeastern:drs:repository:staff', 'northeastern:drs:repository:admin'])
  end

  let(:person) do
    { 'id' => 'cz8wbpk', 'nuid' => '000000004', 'display_name' => 'David Cliff',
      'bio' => 'Builds the DRS.', 'orcid' => '0000-0002-1825-0097',
      'affiliated_community_ids' => ['jm640df'] }
  end

  def page_of(people, page: 1, pages: 1, count: people.size)
    { 'people' => people, 'pagination' => { 'page' => page, 'pages' => pages, 'count' => count } }
  end

  describe 'admin gate' do
    it 'forbids non-admin staff' do
      sign_in staff_user
      get admin_people_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids a devolved-admin delegate (this surface stays :admin-only)' do
      sign_in delegate_user
      get admin_people_path
      expect(response).to have_http_status(:forbidden)
    end

    it 'redirects an anonymous visitor to sign in' do
      get admin_people_path
      expect(response).to have_http_status(:redirect)
    end
  end

  context 'as an admin' do
    before { sign_in admin_user }

    describe 'GET /admin/people' do
      it 'lists the curated people' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([person]))

        get admin_people_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('People registry')
        expect(response.body).to include('David Cliff')
        expect(response.body).to include('000000004') # NUID is fine on this admin surface
      end
    end

    # Atlas pages this list at 10 by default, and the index took that unasked,
    # so everyone past the tenth person was missing.
    describe 'GET /admin/people paging' do
      it 'asks Atlas for a full page, and for the page requested' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([person]))

        get admin_people_path(page: 3)

        expect(AtlasRb::Person).to have_received(:page)
          .with(q: nil, page: 3, per_page: Admin::PeopleController::PER_PAGE, nuid: anything)
      end

      it "shows Atlas's count and page count, and links the next page" do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([person], page: 2, pages: 7, count: 320))

        get admin_people_path(page: 2)

        expect(response.body).to include('320 people', 'Page 2 of 7', admin_people_path(page: 3))
      end

      it 'offers no pagination on a single page' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([person]))
        get admin_people_path
        expect(response.body).not_to include('People pages')
      end

      it 'says there are no more people on an empty later page' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([], page: 2, pages: 1, count: 3))
        get admin_people_path(page: 2)
        expect(response.body).to include('No more people.', admin_people_path)
      end
    end

    describe 'GET /admin/people search' do
      it 'passes the query to Atlas and counts the matches' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([person], count: 1))

        get admin_people_path(q: ' gasp ')

        expect(AtlasRb::Person).to have_received(:page).with(hash_including(q: 'gasp'))
        expect(response.body).to include('1 match for “gasp”', 'value="gasp"')
      end

      # The query must survive paging, or Next lands on the whole registry.
      it 'keeps the query on the page links' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([person], pages: 2, count: 60))
        get admin_people_path(q: 'doe')
        expect(response.body).to include(CGI.escapeHTML(admin_people_path(q: 'doe', page: 2)))
      end

      it 'says so when nothing matches' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([], count: 0, pages: 0))
        get admin_people_path(q: 'zzz')
        expect(response.body).to include('No people match “zzz”.')
        expect(response.body).not_to include('No people registered')
      end
    end

    # v1 showed each user's Grouper groups in an expanding row. Here the row
    # holds a lazy frame, so the index costs no per-person Atlas read.
    describe 'Grouper groups' do
      it 'gives each person with a NUID a lazy groups frame' do
        allow(AtlasRb::Person).to receive(:page).and_return(page_of([person]))
        get admin_people_path
        expect(response.body).to include(%(src="#{groups_admin_person_path('cz8wbpk')}"))
        expect(response.body).to include('loading="lazy"')
      end

      it 'lists each account with its groups, raw ids beside display names' do
        allow(AtlasRb::Person).to receive(:find).and_return(AtlasRb::Mash.new(person))
        allow(AtlasRb::User).to receive(:accounts).with('000000004', nuid: '000000004').and_return(
          AtlasRb::Mash.new('accounts' => [{ 'email' => 'dcliff@example.edu', 'affiliation' => 'staff',
                                             'groups' => ['northeastern:drs:repository:staff'] }])
        )

        get groups_admin_person_path('cz8wbpk')

        expect(response.body).to include('person-groups-cz8wbpk', 'dcliff@example.edu',
                                         'northeastern:drs:repository:staff')
      end

      it 'gives every group a name cell and a raw id chip, named or not' do
        Group.create!(raw: 'test:people:named', cosmetic: 'Named Testers')
        allow(AtlasRb::Person).to receive(:find).and_return(AtlasRb::Mash.new(person))
        allow(AtlasRb::User).to receive(:accounts).and_return(
          AtlasRb::Mash.new('accounts' => [{ 'email'  => 'dcliff@example.edu',
                                             'groups' => ['test:people:named', 'test:people:unnamed'] }])
        )

        get groups_admin_person_path('cz8wbpk')

        page = response.parsed_body
        expect(page.css('.person-groups__name').map(&:text)).to eq(['Named Testers', 'No display name'])
        expect(page.css('.person-groups__list .admin-registry-table__id').map(&:text))
          .to eq(['test:people:named', 'test:people:unnamed'])
        expect(page.css('.person-groups__account-head .person-groups__email').map(&:text))
          .to eq(['dcliff@example.edu'])
      end

      it 'says so when the groups cannot be read' do
        allow(AtlasRb::Person).to receive(:find).and_return(AtlasRb::Mash.new(person))
        allow(AtlasRb::User).to receive(:accounts).and_raise(Faraday::ConnectionFailed, 'down')

        get groups_admin_person_path('cz8wbpk')

        expect(response.body).to include('could not be loaded')
      end
    end

    describe 'GET /admin/people/new' do
      it 'renders the create form' do
        get new_admin_person_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Register a person')
        expect(response.body).to include('person[nuid]')
      end
    end

    describe 'POST /admin/people' do
      it 'creates a Person and redirects to its edit page' do
        expect(AtlasRb::Person).to receive(:create)
          .with(hash_including(nuid: '000000009', display_name: 'New Person'))
          .and_return({ 'id' => 'new1234', 'display_name' => 'New Person' })

        post admin_people_path, params: { person: { nuid: '000000009', display_name: 'New Person',
                                                    bio: 'Joined this week.',
                                                    orcid: '0000-0002-1825-0097' } }

        expect(response).to redirect_to(edit_admin_person_path('new1234'))
      end
    end

    describe 'GET /admin/people/:noid/edit' do
      before do
        allow(AtlasRb::User).to receive(:accounts).and_return(
          AtlasRb::Mash.new('accounts' => [{ 'email' => 'dcliff@example.edu', 'name' => 'Cliff, David A' }])
        )
      end

      it 'renders the identity form and resolves affiliations to community titles' do
        allow(AtlasRb::Person).to receive(:find).with('cz8wbpk', anything).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many).with(['jm640df'], anything)
                                                       .and_return([AtlasRb::Mash.new('noid'  => 'jm640df',
                                                                                      'title' => 'Communications')])

        get edit_admin_person_path('cz8wbpk')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('David Cliff')
        expect(response.body).to include('Community affiliations')
        expect(response.body).to include('Communications') # resolved affiliation title
      end

      # find_many drops an id it cannot resolve, so a stale affiliation comes
      # back absent rather than nil-titled. The row must still render.
      it 'falls back to the bare NOID when an affiliation no longer resolves' do
        allow(AtlasRb::Person).to receive(:find).with('cz8wbpk', anything).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many).and_return([])

        get edit_admin_person_path('cz8wbpk')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('jm640df')
      end

      it 'resolves every affiliation in one call rather than one per NOID' do
        many = { 'id' => 'cz8wbpk', 'nuid' => '000000004', 'display_name' => 'David Cliff',
                 'affiliated_community_ids' => %w[aaa1111 bbb2222 ccc3333] }
        allow(AtlasRb::Person).to receive(:find).with('cz8wbpk', anything).and_return(many)
        expect(AtlasRb::Resource).to receive(:find_many).once
                                                        .with(%w[aaa1111 bbb2222 ccc3333], anything)
                                                        .and_return([])

        get edit_admin_person_path('cz8wbpk')

        expect(response).to have_http_status(:ok)
      end

      # A librarian looking the person up in another system needs the name that
      # system knows, which is the sign-in name, not the curated display name.
      it 'shows the NUID and each account\'s sign-in name above the display name' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many).and_return([])

        get edit_admin_person_path('cz8wbpk')

        readout = response.parsed_body.at_css('.admin-registry-form__readout')
        expect(readout.css('dd .admin-registry-table__id').map(&:text)).to eq(%w[000000004 dcliff@example.edu])
        expect(readout.text).to include('Cliff, David A')
      end

      it 'says a person with no account has not signed in yet' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many).and_return([])
        allow(AtlasRb::User).to receive(:accounts).and_return(AtlasRb::Mash.new('accounts' => []))

        get edit_admin_person_path('cz8wbpk')

        expect(response.body).to include('Not signed in yet.')
      end

      it 'still renders the form when the accounts cannot be read' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many).and_return([])
        allow(AtlasRb::User).to receive(:accounts).and_raise(Faraday::ConnectionFailed, 'down')

        get edit_admin_person_path('cz8wbpk')

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('The sign-in name could not be loaded.', 'person[display_name]')
      end

      # Add and Remove act at once, so they sit in a card of their own and
      # outside the details form that Save submits.
      it 'keeps the affiliation controls out of the details form' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many)
          .and_return([AtlasRb::Mash.new('noid' => 'jm640df', 'title' => 'Communications')])

        get edit_admin_person_path('cz8wbpk')

        page = response.parsed_body
        details = page.at_css("form[action='#{admin_person_path('cz8wbpk')}']")
        expect(details.at_css('.well input[type=submit]')['value']).to eq('Save details')
        expect(details.text).not_to include('Community affiliations')
        expect(page.css('.admin-registry').size).to eq(2)
        expect(page.at_css('.admin-registry__count').text).to eq('1')
      end

      it 'runs the community picker when a query is present' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        allow(AtlasRb::Resource).to receive(:find_many)
          .and_return([AtlasRb::Mash.new('noid' => 'jm640df', 'title' => 'Communications')])
        results = instance_double(Blacklight::Solr::Response, documents: [])
        expect(ResourceSearch).to receive(:call)
          .with(hash_including(query: 'art', types: %w[Community])).and_return(results)

        get edit_admin_person_path('cz8wbpk', q: 'art')

        expect(response).to have_http_status(:ok)
      end
    end

    describe 'PATCH /admin/people/:noid' do
      it 'updates the Person details' do
        allow(AtlasRb::Person).to receive(:find).and_return(person)
        expect(AtlasRb::Person).to receive(:update)
          .with('cz8wbpk', hash_including(display_name: 'David C.')).and_return(person)

        patch admin_person_path('cz8wbpk'),
              params: { person: { display_name: 'David C.', bio: 'Builds the DRS.',
                                  orcid: '0000-0002-1825-0097' } }

        expect(response).to redirect_to(edit_admin_person_path('cz8wbpk'))
      end

      # Otherwise a rename waits out NuidResolver's 12-hour cache.
      it "forgets the person's cached name" do
        allow(AtlasRb::Person).to receive_messages(find: person, update: person)
        expect(NuidResolver).to receive(:forget).with('000000004')

        patch admin_person_path('cz8wbpk'), params: { person: { display_name: 'David C.' } }
      end
    end

    describe 'affiliations' do
      before { allow(AtlasRb::Person).to receive(:find).and_return(person) }

      it 'adds an affiliation' do
        expect(AtlasRb::Person).to receive(:add_affiliation).with('cz8wbpk', 'art9999', anything)

        post add_affiliation_admin_person_path('cz8wbpk'), params: { community_id: 'art9999' }

        expect(response).to redirect_to(edit_admin_person_path('cz8wbpk'))
      end

      it 'removes an affiliation' do
        expect(AtlasRb::Person).to receive(:remove_affiliation).with('cz8wbpk', 'jm640df', anything)

        delete remove_affiliation_admin_person_path('cz8wbpk', community_id: 'jm640df')

        expect(response).to redirect_to(edit_admin_person_path('cz8wbpk'))
      end
    end
  end
end
