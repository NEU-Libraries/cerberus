# frozen_string_literal: true

require 'rails_helper'

# Request specs, not controller specs, so Warden runs — and because the point of
# these is what an unauthenticated caller gets. The consumers are crawlers and
# people following a decade-old link, neither of whom is signed in.
RSpec.describe 'DRS v1 legacy URLs', type: :request do
  # One holder per type Atlas answers, so each destination route is asserted
  # rather than assumed. The v1 prefix is deliberately not always the v2 one.
  HOLDERS = [
    { pid: 'neu:rx918554d', id: 'tqjq4r2', type: 'Work', v1: '/files', v2: '/works' },
    { pid: 'neu:cq77hh55x', id: 'bcc2grg', type: 'Collection', v1: '/collections', v2: '/collections' },
    { pid: 'neu:1', id: '8w9gjsf', type: 'Community', v1: '/communities', v2: '/communities' }
  ].freeze

  def holder(id:, type:, tombstoned: false)
    AtlasRb::Mash.new('id' => id, 'type' => type, 'tombstoned' => tombstoned)
  end

  describe 'a pid that Atlas resolves' do
    before do
      allow(AtlasRb::System).to receive(:find_by_legacy_pid).and_return(nil)
      HOLDERS.each do |h|
        allow(AtlasRb::System).to receive(:find_by_legacy_pid)
          .with(h[:pid]).and_return(holder(id: h[:id], type: h[:type]))
      end
    end

    HOLDERS.each do |h|
      it "redirects a v1 #{h[:type]} URL to its v2 route" do
        get "#{h[:v1]}/#{h[:pid]}"

        expect(response).to have_http_status(:found)
        expect(response.headers['Location']).to end_with("#{h[:v2]}/#{h[:id]}")
      end
    end

    # The prefix only catches the URL; Atlas's type picks the destination.
    it 'follows the type, not the prefix, when the two disagree' do
      get '/collections/neu:rx918554d'
      expect(response.headers['Location']).to end_with('/works/tqjq4r2')
    end

    # There is no 410 branch anywhere: every v1 object migrates. The hand-rolled
    # integers were an argument for fresh NOIDs, not a discard set, and neu:1 is
    # the root Northeastern University Community.
    it 'redirects the hand-rolled integer pid rather than treating it as gone' do
      get '/communities/neu:1'

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to end_with('/communities/8w9gjsf')
    end

    it 'asks on the system path, whoever the visitor is' do
      get '/files/neu:rx918554d'
      expect(AtlasRb::System).to have_received(:find_by_legacy_pid).with('neu:rx918554d')
    end
  end

  # A tombstoned holder keeps its pid, so an old link lands on the tombstone
  # page rather than a 404.
  it 'redirects to a tombstoned holder' do
    allow(AtlasRb::System).to receive(:find_by_legacy_pid)
      .and_return(holder(id: 'tqjq4r2', type: 'Work', tombstoned: true))

    get '/files/neu:rx918554d'
    expect(response.headers['Location']).to end_with('/works/tqjq4r2')
  end

  describe 'a pid that no object holds' do
    before { allow(AtlasRb::System).to receive(:find_by_legacy_pid).and_return(nil) }

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

  # Atlas can answer a type this app has no route for yet, such as a Blob. It
  # must not 500 on a nil path helper.
  it 'renders 404 for a type with no v2 route' do
    allow(AtlasRb::System).to receive(:find_by_legacy_pid)
      .and_return(holder(id: 'abc1234', type: 'Blob'))

    get '/downloads/neu:dl44zz11q'
    expect(response).to have_http_status(:not_found)
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

  # End to end over the test Atlas, so the binding, the route's colon and the
  # system path are proved together. The pid is unique per run because Atlas
  # refuses a pid that another resource holds.
  describe 'against the test Atlas' do
    let(:pid) { "neu:spec#{SecureRandom.hex(4)}" }
    let!(:community) { AtlasRb::Community.create(nil, legacy_pid: pid, nuid: '000000004') }

    it 'redirects to the Community that holds the pid' do
      get "/communities/#{pid}"

      expect(response).to have_http_status(:found)
      expect(response.headers['Location']).to end_with("/communities/#{community['id']}")
    end
  end
end
