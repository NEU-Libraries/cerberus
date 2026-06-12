# frozen_string_literal: true

require 'rails_helper'

# The IIIF manifest endpoint, end-to-end over test Atlas: real Work, real
# ordered page FileSets, real persisted service pointers (the new
# FileSet.set_iiif_service binding). Only the Cantaloupe info.json fetch
# is stubbed — there is no image server in the test stack.
RSpec.describe 'Work IIIF manifests', type: :request do
  include Devise::Test::IntegrationHelpers

  def mods(kind) = "/home/cerberus/web/spec/fixtures/files/#{kind}-mods.xml"
  def read_public = { 'permissions' => { 'read' => ['public'] } }

  let!(:community) do
    c = AtlasRb::Community.create(nil, mods('community'), nuid: '000000004')
    AtlasRb::Community.metadata(c.id, read_public, nuid: '000000004')
    c
  end
  let!(:collection) do
    c = AtlasRb::Collection.create(community.id, mods('collection'), nuid: '000000004')
    AtlasRb::Collection.metadata(c.id, read_public, nuid: '000000004')
    c
  end
  let!(:work) do
    w = AtlasRb::Work.create(collection.id, mods('work'), nuid: '000000004')
    AtlasRb::Work.complete(w.id, nuid: '000000004')
    AtlasRb::Work.metadata(w.id, read_public, nuid: '000000004')
    w
  end

  def add_page(position, service: nil)
    fs = AtlasRb::FileSet.create(work.id, 'image', position: position, nuid: '000000004')
    AtlasRb::FileSet.set_iiif_service(fs['id'], service, nuid: '000000004') if service
    fs
  end

  before do
    allow(Faraday).to receive(:get) do |info_url|
      instance_double(Faraday::Response, success?: true,
                                         body:     { width: 1500, height: 2200, id: info_url }.to_json)
    end
  end

  it 'serves an ordered Presentation 3.0 manifest from persisted service pointers' do
    add_page(2, service: 'https://iiif.test/iiif/3/p2.jp2')
    add_page(1, service: 'https://iiif.test/iiif/3/p1.jp2')

    get "/works/#{work.id}/manifest"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body['type']).to eq('Manifest')
    expect(body['id']).to end_with("/works/#{work.id}/manifest")
    services = body['items'].map { |c| c.dig('items', 0, 'items', 0, 'body', 'service', 0, 'id') }
    expect(services).to eq(['https://iiif.test/iiif/3/p1.jp2', 'https://iiif.test/iiif/3/p2.jp2'])
    expect(body['items'].first).to include('width' => 1500, 'height' => 2200)
  end

  it 'omits pages without a service pointer instead of failing' do
    add_page(1, service: 'https://iiif.test/iiif/3/p1.jp2')
    add_page(2) # blob-only page, never deep-zoomed

    get "/works/#{work.id}/manifest"
    expect(response.parsed_body['items'].size).to eq(1)
  end

  it 'denies the manifest of a private work to anonymous callers' do
    AtlasRb::Work.metadata(work.id,
                           { 'permissions' => { 'read' => [], 'edit' => [] } }, nuid: '000000004')
    get "/works/#{work.id}/manifest"
    expect(response).not_to have_http_status(:ok)
  end
end
