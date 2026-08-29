# frozen_string_literal: true

# Browser specs sign in the way a person does, through the NUID shim, rather
# than through a Warden test helper. The helper writes the session from outside
# the browser, so the browser never receives the cookie and every later request
# it makes arrives as a guest.
module BrowserSignIn
  def sign_in_as(nuid)
    visit atlas_login_path
    fill_in 'user[nuid]', with: nuid
    click_button 'Atlas Login'
    # Wait for the redirect to land before the spec navigates on. Asserting the
    # form is gone rather than the flash text, because the notice differs for a
    # NUID that holds more than one account and that is not what this is for.
    expect(page).to have_no_field('user[nuid]', wait: 5)
  end
end

RSpec.configure do |config|
  config.include BrowserSignIn, type: :system
end
