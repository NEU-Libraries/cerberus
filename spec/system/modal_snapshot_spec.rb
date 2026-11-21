# frozen_string_literal: true

require 'rails_helper'

# Turbo caches a page as it leaves it. A modal open at that moment came back
# open on Back, and its close button did nothing, so the page was stuck behind
# it. Only a real Turbo visit fills the cache, so the spec leaves through the
# modal's own New set link, as a reader would.
RSpec.describe 'A modal open when the page is left', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @collection = create_collection(create_community(public: true).id, public: true)
    @work = create_work(@collection.id, public: true)
  end

  before { sign_in_as(admin_nuid) }

  it 'is closed again after Back' do
    visit "/collections/#{@collection.id}"
    find("[href='#add-to-set-#{@work.id}'], [data-bs-target='#add-to-set-#{@work.id}']").click
    within("#add-to-set-#{@work.id}.show") { click_link 'New set' }
    expect(page).to have_current_path(%r{/sets/new})

    page.go_back

    expect(page).to have_current_path("/collections/#{@collection.id}")
    expect(page).to have_no_css('.modal.show')
    expect(page).to have_no_css('.modal-backdrop')
    expect(page).to have_no_css('body.modal-open')
  end
end
