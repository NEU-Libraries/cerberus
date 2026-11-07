# frozen_string_literal: true

require 'rails_helper'

# An anonymous match-all search of the catalog would list every public record,
# so it is refused; a keyword, a facet, or signing in lists as before.
RSpec.describe 'Anonymous match-all catalog search', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:staff) do
    User.new(email: 'dps@example.com', password: 'password',
             nuid: '000000002', role: 'privileged',
             groups: ['northeastern:drs:repository:staff'])
  end

  [{}, { q: '' }, { q: '*' }, { q: '*:*' }, { q: ' * ' }, { per_page: 100 }].each do |query|
    it "refuses #{query.inspect} with the sign-in page" do
      get search_catalog_path(query)

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include('logging in')
    end
  end

  it 'lists a keyword search' do
    get search_catalog_path(q: 'sample')

    expect(response).to have_http_status(:ok)
  end

  it 'lists a facet without a keyword' do
    get search_catalog_path(f: { type_ssim: ['Work'] })

    expect(response).to have_http_status(:ok)
  end

  it 'lists everything for a signed-in user' do
    sign_in staff
    get search_catalog_path(q: '')

    expect(response).to have_http_status(:ok)
  end

  it 'leaves the public communities listing open' do
    get communities_path

    expect(response).to have_http_status(:ok)
  end
end
