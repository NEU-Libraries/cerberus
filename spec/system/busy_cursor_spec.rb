# frozen_string_literal: true

require 'rails_helper'

# Turbo marks <html> busy for a visit, and a form for its request, and the
# stylesheet turns each into the progress cursor. The risk is a mark left behind,
# which keeps the cursor on progress until the next click. docs/design.md covers it.
RSpec.describe 'The progress cursor while Turbo is busy', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @community = create_community(public: true)
    @collection = create_collection(@community.id, public: true)
  end

  before { sign_in_as(admin_nuid) }

  def busy?
    page.evaluate_script('document.querySelector("[aria-busy]") !== null')
  end

  def link_cursor
    page.evaluate_script('getComputedStyle(document.querySelector("main a[href]")).cursor')
  end

  def search_button_cursor
    page.evaluate_script('getComputedStyle(document.querySelector("#q").form.querySelector("[type=submit]")).cursor')
  end

  def mark_search_form_busy
    page.execute_script('document.querySelector("#q").form.setAttribute("aria-busy", "true")')
  end

  it 'shows on links and buttons only while the page is busy' do
    visit "/collections/#{@collection.id}"
    expect(link_cursor).to eq('pointer')

    page.execute_script('document.documentElement.setAttribute("aria-busy", "true")')
    expect(link_cursor).to eq('progress')
    # Bootstrap's submit-button rule outranks a plain descendant selector.
    expect(search_button_cursor).to eq('progress')
  end

  it 'shows over a busy form only, not the rest of the page' do
    visit "/collections/#{@collection.id}"
    expect(search_button_cursor).to eq('pointer')

    mark_search_form_busy
    expect(search_button_cursor).to eq('progress')
    expect(link_cursor).to eq('pointer')
  end

  it 'is gone after a form submit' do
    visit "/collections/#{@collection.id}"
    fill_in 'q', with: 'busy cursor'
    find_by_id('q').send_keys(:enter)

    expect(page).to have_current_path(/q=busy\+cursor/)
    expect(page).to have_field('q', with: 'busy cursor')
    expect(busy?).to be(false)
    expect(search_button_cursor).not_to eq('progress')
  end

  it 'is gone after a visit, Back and Forward' do
    visit "/collections/#{@collection.id}"
    page.execute_script('Turbo.visit(arguments[0])', "/communities/#{@community.id}")
    expect(page).to have_current_path("/communities/#{@community.id}")
    expect(busy?).to be(false)

    page.go_back
    expect(page).to have_current_path("/collections/#{@collection.id}")
    expect(busy?).to be(false)
    expect(link_cursor).to eq('pointer')

    page.go_forward
    expect(page).to have_current_path("/communities/#{@community.id}")
    expect(busy?).to be(false)
    expect(link_cursor).to eq('pointer')
  end

  # A visit or submit that falls back to a full page load leaves the old
  # document busy in the browser's back-forward cache, and no Turbo request
  # ends to clear it when Back restores that document.
  it 'is cleared when the back-forward cache restores a busy page' do
    visit "/collections/#{@collection.id}"
    mark_search_form_busy
    page.execute_script(<<~JS)
      document.documentElement.setAttribute("aria-busy", "true")
      window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: true }))
    JS

    expect(busy?).to be(false)
    expect(link_cursor).to eq('pointer')
    expect(search_button_cursor).to eq('pointer')
  end
end
