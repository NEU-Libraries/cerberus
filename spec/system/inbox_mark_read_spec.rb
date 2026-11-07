# frozen_string_literal: true

require 'rails_helper'

# The inbox's selection bar is hidden until a row is checked, and counts the
# rows in messages. Only a browser runs bulk_select_controller.js, so that, and
# the round trip through Mark as read, are here.
RSpec.describe 'Inbox mark read', :browser, type: :system do
  let!(:first)  { Message.create!(subject: 'First unread', recipient_nuid: admin_nuid) }
  let!(:second) { Message.create!(subject: 'Second unread', recipient_nuid: admin_nuid) }

  before do
    sign_in_as(admin_nuid)
    visit '/inbox'
  end

  it 'shows the bar once a row is checked, counted in messages, and marks it read' do
    expect(page).to have_css('form#inbox-bulk', visible: :hidden)

    check "select_#{first.id}"

    expect(page).to have_css('form#inbox-bulk .bulk-actions__count', text: '1 message selected')
    click_button 'Mark as read'

    expect(page).to have_text('Marked 1 message as read.')
    expect(page).to have_css('tr.inbox-row--unread', count: 1)
    expect(page).to have_css('tr.inbox-row--unread', text: 'Second unread')
  end

  it 'marks every message read from the header' do
    click_button 'Mark all as read'

    expect(page).to have_text('Marked 2 messages as read.')
    expect(page).to have_no_css('tr.inbox-row--unread')
    expect(page).to have_no_button('Mark all as read')
  end
end
