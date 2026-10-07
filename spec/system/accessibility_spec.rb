# frozen_string_literal: true

require 'rails_helper'
require 'axe-rspec'

# Runs axe-core against the rendered pages, which is where most WCAG failures
# live: a label a helper never emitted, a landmark the layout lacks, a name
# computed from an icon. The template linters cannot see any of those.
#
# Each page runs as the least privileged user who can open it.
module AxeAudit
  # WCAG 2.2 A and AA. axe leaves the 2.2 rules out unless they are named.
  TAGS = %i[wcag2a wcag2aa wcag21a wcag21aa wcag22aa].freeze

  # Known failures whose fix changes how the page looks, so each waits on a
  # design decision. docs/accessibility.md lists the elements behind each one;
  # take a rule out of here when its decision lands.
  SKIPPED = %i[color-contrast link-in-text-block].freeze

  STAFF_NUID = '000000002'
end

RSpec.describe 'Accessibility', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @community = create_community(public: true)
    @collection = create_collection(@community.id, public: true)
    @work = create_work(@collection.id, public: true)
  end

  def expect_axe_clean
    expect(page).to be_axe_clean.according_to(*AxeAudit::TAGS).skipping(*AxeAudit::SKIPPED)
  end

  def self.audits(user, pages)
    context "as #{user || 'a guest'}" do
      before { sign_in_as(send(user)) if user }

      pages.each do |label, path|
        it "#{label} passes axe" do
          visit instance_exec(&path)
          expect_axe_clean
        end
      end
    end
  end

  def staff_nuid = AxeAudit::STAFF_NUID

  audits nil, {
    'the home page'    => -> { root_path },
    'search results'   => -> { search_catalog_path(q: 'test') },
    'zero results'     => -> { search_catalog_path(q: 'zzqqxxnothing') },
    'advanced search'  => -> { '/catalog/advanced' },
    'the communities'  => -> { '/communities' },
    'the people index' => -> { '/people' },
    'the genres'       => -> { '/genres' },
    'the terms'        => -> { '/terms' },
    'a community'      => -> { "/communities/#{@community.id}" },
    'a collection'     => -> { "/collections/#{@collection.id}" },
    'a work'           => -> { "/works/#{@work.id}" },
    'the sign-in page' => -> { atlas_login_path }
  }

  audits :staff_nuid, {
    'My DRS'             => -> { '/my_drs' },
    'the sets'           => -> { '/sets' },
    'a new set'          => -> { '/sets/new' },
    'the inbox'          => -> { '/inbox' },
    'a new message'      => -> { '/inbox/new' },
    'the search history' => -> { '/search_history' }
  }

  audits :admin_nuid, {
    'the deposit form'    => -> { "/collections/#{@collection.id}/works/new" },
    'a new collection'    => -> { "/collections/#{@collection.id}/collections/new" },
    'the work upload'     => -> { "/works/#{@work.id}/upload" },
    'the XML editor'      => -> { "/xml/editor/#{@work.id}" },
    'the admin dashboard' => -> { '/admin' },
    'the ledger'          => -> { '/admin/ledger' },
    'the people registry' => -> { '/admin/people' },
    'a new person'        => -> { '/admin/people/new' },
    'the groups'          => -> { '/admin/groups' },
    'a new group'         => -> { '/admin/groups/new' },
    'the loaders'         => -> { '/admin/loaders' },
    'a new loader'        => -> { '/admin/loaders/new' },
    'maintenance'         => -> { '/admin/maintenance' },
    'impressions'         => -> { '/admin/impressions' },
    'reparent'            => -> { '/admin/reparent' },
    'tombstones'          => -> { '/admin/tombstones' },
    'the file finder'     => -> { '/admin/files' },
    'associations'        => -> { '/admin/associations' },
    'linked members'      => -> { '/admin/linked_members' },
    'impersonation'       => -> { '/admin/impersonation' },
    'deposit triage'      => -> { '/admin/deposit_triage' }
  }

  # axe skips what is not displayed, so each edit pane needs its own visit. The
  # fragment opens the pane, and the tab set comes from the helper so a new tab
  # is audited without an edit here.
  edit_tabs = EditTabsHelper::TABS.flat_map do |klass, keys|
    fixture = { 'Work' => :@work, 'Collection' => :@collection, 'Community' => :@community }.fetch(klass)
    (keys - EditTabsHelper::STANDALONE).map do |key|
      ["the #{klass.downcase} #{key} tab", lambda {
        "/#{klass.downcase.pluralize}/#{instance_variable_get(fixture).id}/edit##{key}"
      }]
    end
  end
  audits :admin_nuid, edit_tabs.to_h
end
