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
    # Wait for the redirect to LAND, not merely for the form to go. The form
    # disappears as the submission starts, so a spec that treats that as done
    # can issue its own visit while the redirect is still in flight — the
    # redirect then arrives last and replaces the page the spec asked for,
    # which reads as an unrelated assertion failure on a page nobody navigated
    # to. The path is the signal; the flash text is not, because the notice
    # differs for a NUID holding more than one account.
    expect(page).to have_current_path(root_path, wait: 5)
  end
end

RSpec.configure do |config|
  config.include BrowserSignIn, type: :system
end
