# frozen_string_literal: true

require 'rails_helper'

# The Add menus have to work from the keyboard (WCAG 2.1.1). axe does
# not test keyboard operation, so this does: the toggle must take focus, which
# an <a> without an href cannot, and Enter must open the menu.
RSpec.describe 'Breadcrumb Add menu', :browser, type: :system do
  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @collection = create_collection(create_community(public: true).id, public: true)
  end

  before { sign_in_as(admin_nuid) }

  it 'takes keyboard focus and opens with Enter' do
    visit "/collections/#{@collection.id}"

    toggle = find_by_id('breadcrumb-add-toggle')
    page.execute_script("document.getElementById('breadcrumb-add-toggle').focus()")
    expect(page.evaluate_script('document.activeElement.id')).to eq('breadcrumb-add-toggle')

    toggle.send_keys(:enter)

    expect(page).to have_css('.breadcrumb-add .dropdown-menu.show')
  end

  # The control under the results is the same menu, opening the other way.
  it 'opens the Add under the results with Enter, to the left of its toggle' do
    visit "/collections/#{@collection.id}"

    page.execute_script("document.getElementById('add-control-toggle').focus()")
    find_by_id('add-control-toggle').send_keys(:enter)

    menu = find('.add-control .dropdown-menu.show')
    expect(menu['data-popper-placement']).to start_with('left')
    expect(menu).to have_link('New Collection').and have_link('New Work')
  end
end
