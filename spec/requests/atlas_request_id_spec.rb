# frozen_string_literal: true

require 'rails_helper'

# Atlas adopts the X-Request-Id it receives and tags its log lines with it, so
# one search finds a page view in both logs. The Work page is the case that
# matters: its reads run on ParallelAtlasReads worker threads, and a worker that
# dropped Current would send no id, or another request's.
RSpec.describe 'Request id sent to Atlas', type: :request do
  def nuid = '000000004'
  def mods(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s
  def read_public = { 'read' => ['public'] }

  def public_container(klass, parent_id)
    container = klass.create(parent_id, mods(klass.name.demodulize.downcase), nuid: nuid)
    AtlasRb::Resource.set_permissions(container.id, read_public, nuid: nuid)
    container
  end

  before(:context) do
    community = public_container(AtlasRb::Community, nil)
    collection = public_container(AtlasRb::Collection, community.id)
    @work = AtlasRb::Work.create(collection.id, mods('work'), nuid: nuid)
    AtlasRb::Work.complete(@work.id, nuid: nuid)
    AtlasRb::Resource.set_permissions(@work.id, read_public, nuid: nuid)
  end

  it "sends the page's own request id on every Atlas call, the parallel reads included" do
    sent = Queue.new
    allow(AtlasRb::Transport::Proxy).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap { |proxy| sent << [proxy.headers['X-Request-Id'], Thread.current] }
    end

    get work_path(@work.id)

    expect(response).to have_http_status(:ok)
    calls = Array.new(sent.size) { sent.pop }
    expect(calls.map(&:last).uniq.size).to be > 1
    expect(calls.map(&:first).uniq).to eq([response.headers['X-Request-Id']])
  end

  # Sending the id proves only Cerberus's half. Atlas echoes the id it adopted,
  # so every Atlas response must carry the page's id back, or Atlas logs under
  # an id of its own.
  it "gets the page's request id back from Atlas on every call" do
    echoed = Queue.new
    subscriber = ActiveSupport::Notifications.subscribe('request.atlas_rb') do |*args|
      echoed << ActiveSupport::Notifications::Event.new(*args).payload.response_headers&.[]('x-request-id')
    end

    get work_path(@work.id)

    ids = Array.new(echoed.size) { echoed.pop }
    expect(ids).not_to be_empty
    expect(ids.uniq).to eq([response.headers['X-Request-Id']])
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
