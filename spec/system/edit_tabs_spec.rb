# frozen_string_literal: true

require 'rails_helper'

# The edit-page tab row exists only in a browser: the panes are Bootstrap tabs
# and the row is driven by the tab-hash controller. Three behaviours matter here
# and a request spec can see none of them — a deep link opening the pane it
# names, a click writing that pane into the URL, and a fragment-only navigation
# moving the row without loading a document.
RSpec.describe 'Edit page tabs', :browser, type: :system do
  before(:all) do
    Current.nuid = admin_nuid
    @work = create_editable_work
  end

  before { sign_in_as(admin_nuid) }

  it 'opens the pane named by the fragment' do
    visit "#{edit_work_path(@work.id)}#permissions"

    expect(page).to have_css('#permissions.active')
    expect(page).to have_no_css('#metadata.active')
  end

  it 'writes the opened pane into the URL when a tab is clicked' do
    visit edit_work_path(@work.id)
    expect(page).to have_css('#metadata.active')

    click_button 'History'

    expect(page).to have_css('#history.active')
    expect(page.evaluate_script('window.location.hash')).to eq('#history')
  end

  it 'follows a fragment-only navigation, which loads no document' do
    visit "#{edit_work_path(@work.id)}#permissions"
    expect(page).to have_css('#permissions.active')

    # Assigning the hash is what following an in-page link does. No document
    # loads, so connect() never runs again and only the hashchange listener can
    # move the row.
    page.execute_script("window.location.hash = '#advanced'")

    expect(page).to have_css('#advanced.active')
  end

  # --- helpers ---------------------------------------------------------------

  def admin_nuid = '000000004'

  def mods_path(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s

  # A Work has to sit under a Collection under a Community, and it has to be
  # complete before the edit page will offer it.
  def create_editable_work
    community = AtlasRb::Community.create(nil, mods_path('community'), nuid: admin_nuid)
    collection = AtlasRb::Collection.create(community.id, mods_path('collection'), nuid: admin_nuid)
    work = AtlasRb::Work.create(collection.id, mods_path('work'), nuid: admin_nuid)
    AtlasRb::Work.complete(work.id, nuid: admin_nuid)
    work
  end
end
