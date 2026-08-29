# frozen_string_literal: true

require 'rails_helper'

# The first browser spec, and deliberately the shallowest one. It asks only
# whether this lane works at all: a real Chrome in the sibling container
# reaching a Capybara server in this one, the stylesheet and the importmapped
# JavaScript both loading, and a session surviving a form post.
#
# Every other browser spec rests on all of that, so when a batch of them goes
# red together, read this file first. A failure here is the environment. A
# failure only in the others is the code.
RSpec.describe 'Browser lane smoke', :browser, type: :system do
  it 'loads a page and applies its stylesheet' do
    visit root_path

    expect(page).to have_css('body')
    # Bootstrap's reboot sets box-sizing on every element, so an unstyled
    # document reports the CSS default of content-box. Asserting the computed
    # value proves the browser fetched the stylesheet and applied it, which a
    # server-side render check cannot distinguish from a 404 on the asset.
    expect(computed_style('body', 'boxSizing')).to eq('border-box')
  end

  it 'boots Stimulus, so later specs can rely on controllers connecting' do
    visit root_path

    expect(page).to have_css('body')
    expect(page.evaluate_script('typeof window.Stimulus')).to eq('object')
  end

  it 'signs in through the browser and keeps the session' do
    visit atlas_login_path
    fill_in 'user[nuid]', with: '000000002'
    click_button 'Atlas Login'

    expect(page).to have_content('You have successfully signed in.')
  end

  # --- helpers ---------------------------------------------------------------

  def computed_style(selector, property)
    page.evaluate_script(
      "window.getComputedStyle(document.querySelector('#{selector}')).#{property}"
    )
  end
end
