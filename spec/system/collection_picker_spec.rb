# frozen_string_literal: true

require 'rails_helper'

# The loader's destination picker: a debounced title search that fills a hidden
# field with the chosen collection's identifier. What a request spec can reach
# is the endpoint the typeahead calls; what decides whether an operator sends a
# batch to the right place is the field the form actually submits, and only a
# browser sets that.
RSpec.describe 'Loader destination picker', :browser, type: :system do
  let!(:loader) do
    Loader.create!(slug: 'picker-spec', display_name: 'XML Metadata Loader',
                   group: 'northeastern:drs:repository:loaders:picker-spec',
                   root_collection: 'neu:root', kind: :xml)
  end

  before(:all) do
    Current.nuid = AtlasFixtures::ADMIN_NUID
    @collection = create_collection(create_community(public: true).id, public: true)
  end

  before do
    sign_in_as(admin_nuid)
    visit new_loader_load_path(loader.slug)
  end

  it 'offers nothing until the query is long enough to be one' do
    fill_in 'load_report_collection_query', with: 'T'

    expect(page).to have_no_css('.inbox-typeahead .list-group-item')
  end

  it 'searches by title once there is a query' do
    fill_in 'load_report_collection_query', with: 'Test Collection'

    expect(page).to have_css('.inbox-typeahead .list-group-item', minimum: 1)
  end

  it 'submits the identifier of the destination that was picked' do
    fill_in 'load_report_collection_query', with: 'Test Collection'
    result = first('.inbox-typeahead .list-group-item')
    chosen = result['data-value']

    result.click

    expect(submitted_destination).to eq(chosen)
    # The visible field echoes the identifier too, which is what lets an
    # operator confirm the pick against a bad paste.
    expect(page).to have_field('load_report_collection_query', with: /\(#{Regexp.escape(chosen)}\)\z/)
  end

  it 'submits a pasted identifier without a pick' do
    fill_in 'load_report_collection_query', with: @collection.id

    expect(submitted_destination).to eq(@collection.id)
  end

  # --- helpers ---------------------------------------------------------------

  # The field the form posts, as opposed to the one the operator types into.
  def submitted_destination
    find('#load_report_parent_collection_id', visible: :all).value
  end
end
