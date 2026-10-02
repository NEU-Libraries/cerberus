# frozen_string_literal: true

require 'rails_helper'

# The /communities index the homepage Communities gateway opens. It is a
# Community-scoped Blacklight search, so these check the page around the
# results rather than which communities the test corpus happens to hold.
RSpec.describe 'Communities index', type: :request do
  it 'names the page and heads it like the other browse pages' do
    get communities_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<title>Communities')
    html = response.parsed_body
    expect(html.at_css('.well h3').text.strip).to eq('Communities')
    expect(html.at_css('.well').text).to include('Browse Northeastern departments and groups by name.')
  end

  it 'searches within communities' do
    get communities_path, params: { q: 'library' }

    expect(response.parsed_body.at_css("form.scoped-search[action='#{communities_path}']")).to be_present
  end

  # With no query there is nothing to rank, so the list reads alphabetically.
  # Checked on the search state Blacklight queries with, not on params: a params
  # default set too late passed a params check while the page sorted by relevance.
  it 'sorts by title when there is no query, and keeps relevance for a search' do
    get communities_path
    expect(controller.search_state.sort_field.key).to eq('title')

    get communities_path, params: { q: 'library' }
    expect(controller.search_state.sort_field.key).to eq('relevance')
  end

  it 'keeps a sort the visitor chose' do
    get communities_path, params: { sort: 'date-added' }
    expect(controller.search_state.sort_field.key).to eq('date-added')
  end
end
