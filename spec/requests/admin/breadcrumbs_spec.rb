# frozen_string_literal: true

require 'rails_helper'

# Every admin surface carries a consistent breadcrumb trail (Administration /
# <section>), built in Admin::BaseController and rendered per-view into
# :container_header — replacing the old ad-hoc per-page "Back to admin" links.
# The hub (dashboard) shows none. Assertions are scoped to the breadcrumb nav
# (not the page at large) so a stray /admin link elsewhere — e.g. the navbar —
# can't mask a crumb that should be a link but isn't.
RSpec.describe 'Admin breadcrumbs', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end

  before { sign_in admin_user }

  # [{ text:, href:, active: }, ...] for each crumb in the breadcrumb nav.
  def crumbs
    nav = response.parsed_body.at_css('nav[aria-label="breadcrumb"]')
    return [] unless nav

    nav.css('.breadcrumb-item').map do |li|
      link = li.at_css('a')
      { text: li.text.strip, href: link&.[]('href'), active: li['class'].to_s.include?('active') }
    end
  end

  it 'shows no breadcrumb on the admin hub (you are already there)' do
    get '/admin'

    expect(response).to have_http_status(:ok)
    expect(crumbs).to be_empty
  end

  it 'links Administration back to the hub (not a dead current crumb) on a section page' do
    get '/admin/people'

    expect(response).to have_http_status(:ok)
    admin_crumb = crumbs.first
    expect(admin_crumb[:text]).to eq('Administration')
    expect(admin_crumb[:href]).to eq(admin_root_path) # it is a link…
    expect(admin_crumb[:active]).to be(false)         # …not the current crumb

    # The section is the current (active, non-link) leaf.
    expect(crumbs.last).to include(text: 'Manage people', active: true)
    expect(crumbs.last[:href]).to be_nil
  end

  it 'keeps Administration and the section as links, with the sub-page as the leaf' do
    get '/admin/groups/new'

    expect(response).to have_http_status(:ok)
    texts = crumbs.pluck(:text)
    expect(texts).to eq(['Administration', 'Group names', 'New'])
    expect(crumbs[0]).to include(href: admin_root_path, active: false)   # Administration link
    expect(crumbs[1]).to include(href: admin_groups_path, active: false) # Group names link
    expect(crumbs[2]).to include(active: true)                           # New (current)
  end

  it 'is rendered on the Replace-a-file surface (previously a bare back-link)' do
    get '/admin/files'

    expect(response).to have_http_status(:ok)
    expect(crumbs.pluck(:text)).to eq(['Administration', 'Replace a file'])
    expect(crumbs.first).to include(href: admin_root_path, active: false)
  end
end
