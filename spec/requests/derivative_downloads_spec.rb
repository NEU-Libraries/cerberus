# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Derivative downloads', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:work_id) { 'w-1' }
  let(:uri) { 'https://gated.example/iiif/3/abc.jp2/full/pct:75/0/default.jpg' }

  before do
    allow(Rails.application.config.x.cerberus).to receive(:iiif_signing_secret).and_return('s3cret')
    # The embargo gate reads the Work's own permissions; default unembargoed,
    # overridden per example in the "under an active embargo" context below.
    allow(AtlasRb::Resource).to receive(:permissions).with(work_id).and_return(AtlasRb::Mash.new('embargo' => ''))
  end

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

  # The redirect target is Cantaloupe, so the browser obeys its headers: with no
  # disposition the JPEG renders in a tab and a control labelled Download does
  # not download. Appending after signing is safe — the HMAC covers the path.
  it 'asks Cantaloupe for an attachment, named by tier and work' do
    stub_tier(gated: false, permission: ['public'], nuid: nil)

    get derivative_download_path(work_id, 'large_image')

    # The route param here is the tier `use` verbatim; in the app that is a
    # display label ("Large Image"), which parameterizes to "large-image".
    disposition = CGI.unescape(response.location[/response-content-disposition=(.+)\z/, 1])
    expect(disposition).to eq(%(attachment; filename="large_image_#{work_id}.jpg"; ) +
                              %(filename*=UTF-8''large_image_#{work_id}.jpg))
    expect(response.location).to match(/\?exp=\d+&sig=[a-f0-9]+&response-content-disposition=/)
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

  context 'under an active embargo' do
    before do
      allow(AtlasRb::Resource).to receive(:permissions).with(work_id)
                                                       .and_return(AtlasRb::Mash.new('embargo' => (Date.current + 30).to_s))
    end

    it 'forbids an otherwise-public tier for a guest' do
      stub_tier(gated: false, permission: ['public'], nuid: nil)
      get derivative_download_path(work_id, 'large_image')
      expect(response).to have_http_status(:forbidden)
    end

    it 'allows a member of the staff grouper group' do
      sign_in User.new(email: 's@x.edu', password: 'password', nuid: '000000002',
                       groups: [Permissions::STAFF_EDIT_GROUP])
      stub_tier(gated: false, permission: ['public'], nuid: '000000002')
      get derivative_download_path(work_id, 'large_image')
      expect(response).to have_http_status(:found)
    end

    it 'allows an Admin' do
      sign_in User.new(email: 'a@x.edu', password: 'password', nuid: '000000004', groups: [], role: 'admin')
      stub_tier(gated: false, permission: ['public'], nuid: '000000004')
      get derivative_download_path(work_id, 'large_image')
      expect(response).to have_http_status(:found)
    end
  end
end
