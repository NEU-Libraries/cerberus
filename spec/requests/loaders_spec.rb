# frozen_string_literal: true

require 'rails_helper'

# The "My Loaders" interstitial: coarse role gate, group-scoped registry
# rows, and the user-menu entry's precise gating. Per-loader enforcement
# on the nested loads pages is covered in loads_spec.
RSpec.describe 'Loaders (My Loaders)', type: :request do
  include Devise::Test::IntegrationHelpers

  let!(:marcom) do
    Loader.create!(slug: 'marcom', display_name: 'Marketing and Communications',
                   kind: :iptc, group: 'northeastern:drs:repository:loaders:marcom',
                   root_collection: 'abc1234')
  end
  let!(:xml_loader) do
    Loader.create!(slug: 'xml', display_name: 'XML Metadata Loader',
                   kind: :xml, group: 'northeastern:drs:repository:loaders:xml',
                   root_collection: 'def5678')
  end

  def user(role:, groups: [])
    User.new(email: "#{role}@example.com", password: 'password', name: 'Lo Ader',
             nuid: '000000003', role: role, groups: groups)
  end

  it 'redirects anonymous visitors to sign in' do
    get '/loaders'
    expect(response).to redirect_to(new_user_session_path)
  end

  it '403s users below the loader tier' do
    sign_in user(role: 'guest')
    get '/loaders'
    expect(response).to have_http_status(:forbidden)
  end

  it 'lists only the loaders the user’s groups unlock, with launch links' do
    sign_in user(role: 'loader', groups: [marcom.group])
    get '/loaders'
    expect(response.body).to include('Marketing and Communications')
      .and include(new_loader_load_path(marcom))
      .and include(loader_loads_path(marcom))
    expect(response.body).not_to include('XML Metadata Loader')
  end

  it 'shows staff without loader groups the empty state' do
    sign_in user(role: 'privileged')
    get '/loaders'
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No loaders are assigned to you yet')
  end

  it 'shows admins the whole registry' do
    sign_in user(role: 'admin')
    get '/loaders'
    expect(response.body).to include('Marketing and Communications')
      .and include('XML Metadata Loader')
  end

  describe 'the user-menu entry' do
    it 'appears for a user with an unlocked loader' do
      sign_in user(role: 'loader', groups: [marcom.group])
      get '/'
      expect(response.body).to include('My Loaders')
        .and include(loaders_path)
    end

    it 'stays hidden for staff without loader groups' do
      sign_in user(role: 'privileged')
      get '/'
      expect(response.body).not_to include('My Loaders')
    end
  end
end
