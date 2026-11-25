# frozen_string_literal: true

require 'rails_helper'

# Turbo marks <html> busy for the length of a visit, and the stylesheet turns
# that into the progress cursor. The risk is a page left marked busy, which
# keeps the cursor on progress until the next click. docs/design.md covers it.
RSpec.describe 'The progress cursor during a Turbo visit', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @community = create_community(public: true)
    @collection = create_collection(@community.id, public: true)
  end

  before { sign_in_as(admin_nuid) }

  def busy?
    page.evaluate_script('document.documentElement.hasAttribute("aria-busy")')
  end

  def link_cursor
    page.evaluate_script('getComputedStyle(document.querySelector("main a[href]")).cursor')
  end

  it 'shows on links and buttons only while the page is busy' do
    visit "/collections/#{@collection.id}"
    expect(link_cursor).to eq('pointer')

    page.execute_script('document.documentElement.setAttribute("aria-busy", "true")')
    expect(link_cursor).to eq('progress')
    expect(page.evaluate_script('getComputedStyle(document.querySelector(".btn")).cursor')).to eq('progress')
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

  # A visit that falls back to a full page load leaves the old document busy
  # in the browser's back-forward cache, and no Turbo visit completes to clear
  # it when Back restores that document.
  it 'is cleared when the back-forward cache restores a busy page' do
    visit "/collections/#{@collection.id}"
    page.execute_script(<<~JS)
      document.documentElement.setAttribute("aria-busy", "true")
      window.dispatchEvent(new PageTransitionEvent("pageshow", { persisted: true }))
    JS

    expect(busy?).to be(false)
    expect(link_cursor).to eq('pointer')
  end
end
