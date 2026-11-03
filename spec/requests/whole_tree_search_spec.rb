# frozen_string_literal: true

require 'rails_helper'

# A collection or community page searched with an empty box lists everything
# beneath it; opening the page, or narrowing it with a facet, lists one level.
# Over the real test Atlas.
RSpec.describe 'Whole-tree search', type: :request do
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

  # community > collection > { shallow work, sub-collection > deep work }
  before(:context) do
    @community  = public_container(AtlasRb::Community, nil)
    @collection = public_container(AtlasRb::Collection, @community.id)
    @sub        = public_container(AtlasRb::Collection, @collection.id)
    @shallow    = public_work(@collection.id, 'sample-audio')
    @deep       = public_work(@sub.id, 'sample-video')
  end

  def listed_ids
    response.parsed_body.css('#documents article[data-document-id]').pluck('data-document-id')
  end

  def chip
    response.parsed_body.at_css('#appliedParams .whole-tree')
  end

  describe 'a collection page' do
    it 'lists one level when opened' do
      get collection_path(@collection.id)

      expect(listed_ids).to contain_exactly(@shallow.valkyrie_id, @sub.valkyrie_id)
      expect(chip).to be_nil
    end

    it 'lists the whole tree for an empty search, by title, under a chip' do
      get collection_path(@collection.id, q: '')

      expect(listed_ids).to contain_exactly(@shallow.valkyrie_id, @sub.valkyrie_id, @deep.valkyrie_id)
      expect(controller.send(:search_state).sort_field.key).to eq('title')
      expect(chip.at_css('.filter-value').text.strip).to eq('Everything in this collection')
      expect(response.parsed_body.at_css('.search-results-header__title')).to be_present
    end

    it 'goes back to one level from the chip, keeping a facet' do
      get collection_path(@collection.id, q: '', f: { type_ssim: ['Work'] })

      remove = chip.at_css('a.remove')['href']
      expect(remove).to start_with(collection_path(@collection.id))
      expect(remove).not_to include('q=')
      expect(remove).to include('type_ssim')
    end

    # Blacklight drops only nil params, so the blank q must survive into the
    # links; without it the second click would fall back to one level.
    it 'keeps the empty search in its facet links' do
      get collection_path(@collection.id, q: '')

      hrefs = response.parsed_body.css('#facets a[href]').pluck('href')
      expect(hrefs).not_to be_empty
      expect(hrefs).to all(include('q='))
    end

    it 'narrows one level only for a facet without a search' do
      get collection_path(@collection.id, f: { type_ssim: ['Work'] })

      expect(listed_ids).to eq([@shallow.valkyrie_id])
    end

    it 'narrows the whole tree for a facet with an empty search' do
      get collection_path(@collection.id, q: '', f: { type_ssim: ['Work'] })

      expect(listed_ids).to contain_exactly(@shallow.valkyrie_id, @deep.valkyrie_id)
    end

    # The modal shares child_membership_filters, so its counts follow the page.
    it 'counts the whole tree in the facet modal for an empty search' do
      work_count = lambda do
        rows = response.parsed_body.css('.facet-values li')
        row = rows.find { |li| li.at_css('.facet-label').text.strip == 'Work' }
        row.at_css('.facet-count').text.strip
      end

      get facet_collection_path(id: @collection.id, facet_field: 'type_ssim')
      expect(work_count.call).to eq('1')

      get facet_collection_path(id: @collection.id, facet_field: 'type_ssim', q: '')
      expect(work_count.call).to eq('2')
    end
  end

  it 'lists the whole tree for an empty search on a community' do
    get community_path(@community.id, q: '')

    expect(listed_ids).to include(@deep.valkyrie_id)
    expect(chip.at_css('.filter-value').text.strip).to eq('Everything in this community')
  end

  it 'shows no chip for an empty search of the catalog' do
    get search_catalog_path(q: '')

    expect(chip).to be_nil
  end
end
