# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_flash_msg' do
  it 'appends a follow-up link to the notice' do
    flash[:notice] = 'The item has been restored.'
    flash[:notice_link] = { 'label' => 'View it', 'path' => '/works/abc1234' }

    render

    expect(rendered).to have_css('.alert-info', text: 'The item has been restored. View it')
    expect(rendered).to have_link('View it', href: '/works/abc1234')
  end

  # The path arrives through the session, so only an app-internal one is linked.
  it 'ignores a link that is not an app path' do
    flash[:notice] = 'Done.'
    flash[:notice_link] = { 'label' => 'Elsewhere', 'path' => 'https://example.com/' }

    render

    expect(rendered).to have_css('.alert-info', text: 'Done.')
    expect(rendered).not_to have_link('Elsewhere')
  end

  it 'escapes the notice text itself' do
    flash[:alert] = '<b>raw</b>'

    render

    expect(rendered).to include('&lt;b&gt;raw&lt;/b&gt;')
  end
end
