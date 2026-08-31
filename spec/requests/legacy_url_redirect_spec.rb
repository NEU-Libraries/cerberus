# frozen_string_literal: true

require 'rails_helper'

# Request specs, not controller specs, so Warden runs — and because the point of
# these is what an unauthenticated caller gets. The consumers are crawlers and
# people following a decade-old link, neither of whom is signed in.
#
# No Atlas stubbing: the redirect is built from the mapping row alone, which is
# the design's reason for storing object_type. Nothing here reaches Atlas, and
# these specs prove it by never arranging for it to answer.
RSpec.describe 'DRS v1 legacy URLs', type: :request do
  after(:all) { LegacyIdentifier.delete_all }

  # One mapping per object type, so each destination route is asserted rather
  # than assumed. The v1 prefix is deliberately not always the v2 one.
  MAPPINGS = [
    { pid: 'neu:rx918554d', noid: 'tqjq4r2', object_type: 'work', v1: '/files', v2: '/works' },
    { pid: 'neu:cq77hh55x', noid: 'bcc2grg', object_type: 'collection', v1: '/collections', v2: '/collections' },
    { pid: 'neu:1', noid: '8w9gjsf', object_type: 'community', v1: '/communities', v2: '/communities' },
    { pid: 'neu:dl44zz11q', noid: '9zw3s1h', object_type: 'download', v1: '/downloads', v2: '/downloads' },
    { pid: 'neu:st22yy88w', noid: '3r228cr', object_type: 'set', v1: '/sets', v2: '/sets' }
  ].freeze

  before do
    MAPPINGS.each do |m|
      LegacyIdentifier.find_or_create_by!(pid: m[:pid]) do |record|
        record.noid = m[:noid]
        record.object_type = m[:object_type]
      end
    end
  end

  MAPPINGS.each do |m|
    it "redirects a v1 #{m[:object_type]} URL to its v2 route" do
      get "#{m[:v1]}/#{m[:pid]}"

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to end_with("#{m[:v2]}/#{m[:noid]}")
    end
  end

  # The most-cited v1 shape, and the one where the prefix changes. Called out
  # separately because a redirect that kept /files would 404 in v2.
  it 'sends the most-cited shape /files/:pid to /works/:noid' do
    get '/files/neu:rx918554d'
    expect(response.headers['Location']).to end_with('/works/tqjq4r2')
  end

  # There is no 410 branch anywhere: every v1 object migrates. The hand-rolled
  # integers were an argument for fresh NOIDs, not a discard set, and neu:1 is
  # the root Northeastern University Community.
  it 'redirects the hand-rolled integer pid rather than treating it as gone' do
    get '/communities/neu:1'

    expect(response).to have_http_status(:found)
    expect(response).not_to have_http_status(:gone)
    expect(response.headers['Location']).to end_with('/communities/8w9gjsf')
  end

  it 'serves the redirect to a caller who is not signed in' do
    get '/files/neu:rx918554d'
    expect(response).to have_http_status(:found)
  end

  describe 'a pid with no mapping' do
    it 'renders 404 rather than redirecting' do
      get '/files/neu:neverexisted'

      expect(response).to have_http_status(:not_found)
      expect(response.headers['Location']).to be_nil
    end

    it 'names a page rather than the controller in the message' do
      get '/files/neu:neverexisted'
      expect(response.body).to include('the page you requested was not found')
    end
  end

  # The legacy routes are declared before the v2 resources they share a prefix
  # with, so this is the guard that they only ever capture a v1-shaped id. A v2
  # NOID never contains a colon.
  describe 'the v2 routes it sits in front of' do
    it 'does not capture a v2 NOID on a shared prefix' do
      expect(Rails.application.routes.recognize_path('/collections/bcc2grg', method: :get))
        .to include(controller: 'collections', action: 'show')
    end

    it 'does capture a v1 pid on that same prefix' do
      expect(Rails.application.routes.recognize_path('/collections/neu:1', method: :get))
        .to include(controller: 'legacy', action: 'show')
    end
  end

  # Rows come from migration tooling outside this app, so a value the model's
  # validation never saw can reach the controller. It must not 500 on a nil path
  # helper.
  describe 'a mapping the app has no route for' do
    before do
      record = LegacyIdentifier.new(pid: 'neu:orphan', noid: 'abc1234', object_type: 'employee')
      record.save!(validate: false)
    end

    it 'renders 404 rather than raising' do
      get '/files/neu:orphan'
      expect(response).to have_http_status(:not_found)
    end
  end
end
