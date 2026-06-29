# frozen_string_literal: true

require 'rails_helper'

# Every admin surface carries a consistent breadcrumb trail (Administration /
# <section>), rendered by the `admin` layout from the trail built in
# Admin::BaseController — replacing the old ad-hoc per-page "Back to admin"
# links. The hub (dashboard) shows none.
RSpec.describe 'Admin breadcrumbs', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin_user) do
    User.new(email: 'admin@example.com', password: 'password',
             nuid: '000000004', name: 'User, Admin', role: 'admin')
  end

  before { sign_in admin_user }

  it 'shows no breadcrumb on the admin hub (you are already there)' do
    get '/admin'

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('aria-label="breadcrumb"')
  end

  it 'trails Administration / <section> on a section page, linking back to the hub' do
    get '/admin/groups'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('aria-label="breadcrumb"')
    expect(response.body).to include(%(href="#{admin_root_path}")) # Administration → hub
    expect(response.body).to include('Group names')
  end

  it 'keeps the section as a back-link and adds a leaf on a sub-page' do
    get '/admin/groups/new'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('aria-label="breadcrumb"')
    expect(response.body).to include(%(href="#{admin_root_path}"))   # Administration link
    expect(response.body).to include(%(href="#{admin_groups_path}")) # Group names still a link
  end

  it 'is rendered on the Replace-a-file surface (previously a bare back-link)' do
    get '/admin/files'

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('aria-label="breadcrumb"')
    expect(response.body).to include('Replace a file')
  end
end
