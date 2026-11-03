# frozen_string_literal: true

require 'rails_helper'

# A collection or community page with no query lists by title; a search ranks by
# relevance; a sort the visitor picks wins. Over the real test Atlas.
RSpec.describe 'Container browse sort', type: :request do
  def nuid = '000000004'
  def mods(kind) = Rails.root.join("spec/fixtures/files/#{kind}-mods.xml").to_s
  def read_public = { 'read' => ['public'] }

  def public_container(klass, parent_id)
    container = klass.create(parent_id, mods(klass.name.demodulize.downcase), nuid: nuid)
    AtlasRb::Resource.set_permissions(container.id, read_public, nuid: nuid)
    container
  end

  def public_work(parent_id, fixture)
    work = AtlasRb::Work.create(parent_id, mods(fixture), nuid: nuid)
    AtlasRb::Work.complete(work.id, nuid: nuid)
    AtlasRb::Resource.set_permissions(work.id, read_public, nuid: nuid)
    work
  end

  # A to Z in creation order, so newest-first (relevance's tie-break with no
  # query) lists them Z to A and only a title sort lists them A to Z.
  before(:context) do
    @community  = public_container(AtlasRb::Community, nil)
    @collection = public_container(AtlasRb::Collection, @community.id)
    @audio = public_work(@collection.id, 'sample-audio')
    @video = public_work(@collection.id, 'sample-video')
  end

  def listed_ids
    response.parsed_body.css('#documents article[data-document-id]').pluck('data-document-id')
  end

  def selected_sort
    response.parsed_body.at_css('#sort-dropdown .dropdown-item.active')&.text&.strip
  end

  describe 'a collection page' do
    it 'lists by title with no query, and shows title as the sort' do
      get collection_path(@collection.id)

      expect(response).to have_http_status(:ok)
      expect(controller.send(:search_state).sort_field.key).to eq('title')
      expect(listed_ids).to eq([@audio.valkyrie_id, @video.valkyrie_id])
      expect(selected_sort).to eq('title')
    end

    it 'ranks a search by relevance' do
      get collection_path(@collection.id, q: 'sample')

      expect(controller.send(:search_state).sort_field.key).to eq('relevance')
    end

    it 'keeps a sort the visitor picked' do
      get collection_path(@collection.id, sort: 'date-added')

      expect(controller.send(:search_state).sort_field.key).to eq('date-added')
      expect(listed_ids).to eq([@video.valkyrie_id, @audio.valkyrie_id])
    end

    # The default must not ride the page's links: a facet clicked on a browse,
    # then a search typed into the box, would otherwise sort that search by title.
    it 'leaves sort out of the links the page builds' do
      get collection_path(@collection.id)

      hrefs = response.parsed_body.css('#facets a[href]').pluck('href')
      expect(hrefs).not_to be_empty
      expect(hrefs).to all(satisfy { |href| !href.include?('sort=') })
    end
  end

  describe 'a community page' do
    it 'lists by title with no query, and ranks a search by relevance' do
      get community_path(@community.id)
      expect(controller.send(:search_state).sort_field.key).to eq('title')

      get community_path(@community.id, q: 'sample')
      expect(controller.send(:search_state).sort_field.key).to eq('relevance')
    end
  end

  it 'leaves the catalog on relevance' do
    get search_catalog_path

    expect(controller.send(:search_state).sort_field.key).to eq('relevance')
  end
end
