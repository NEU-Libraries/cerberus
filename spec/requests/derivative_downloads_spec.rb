# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Derivative downloads', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:work_id) { 'w-1' }
  let(:uri) { 'https://gated.example/iiif/3/abc.jp2/full/pct:75/0/default.jpg' }

  before { allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return('s3cret') }

  def stub_tier(gated:, permission:, nuid:, use: 'large_image')
    allow(AtlasRb::Work).to receive(:assets).with(work_id, nuid: nuid)
                                            .and_return([AtlasRb::Mash.new(use: use, uri: uri, gated: gated,
                                                                           permission: permission)])
  end

  it 'redirects a public tier to a size-bound signed URL for anyone (guest)' do
    stub_tier(gated: false, permission: ['public'], nuid: nil)

    get derivative_download_path(work_id, 'large_image')

    expect(response).to have_http_status(:found)
    expect(response.location).to start_with("#{uri}?exp=").and include('&sig=')
  end

  it 'redirects a gated tier for a member of a gating group' do
    sign_in User.new(email: 'm@x.edu', password: 'password', nuid: '000000004', groups: ['g:arch'])
    stub_tier(gated: true, permission: ['g:arch'], nuid: '000000004')

    get derivative_download_path(work_id, 'large_image')

    expect(response).to have_http_status(:found)
  end

  it 'forbids a gated tier for a signed-in non-member' do
    sign_in User.new(email: 'o@x.edu', password: 'password', nuid: '000000005', groups: ['g:other'])
    stub_tier(gated: true, permission: ['g:arch'], nuid: '000000005')

    get derivative_download_path(work_id, 'large_image')

    expect(response).to have_http_status(:forbidden)
  end

  it 'forbids a gated tier for a guest (groups withheld → permission nil)' do
    stub_tier(gated: true, permission: nil, nuid: nil)

    get derivative_download_path(work_id, 'large_image')

    expect(response).to have_http_status(:forbidden)
  end

  it '404s an unknown tier' do
    stub_tier(gated: false, permission: ['public'], nuid: nil)

    get derivative_download_path(work_id, 'nonexistent')

    expect(response).to have_http_status(:not_found)
  end
end
