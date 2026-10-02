# frozen_string_literal: true

require 'rails_helper'

# The header search form on every page. It carries the search state into the
# next search, but not the query, which its own box supplies, nor the route's
# parameters.
RSpec.describe 'The header search form', type: :request do
  def hidden_fields
    form = response.parsed_body.at_css('form.search-query-form')
    form.css('input[type=hidden]').to_h { |input| [input['name'], input['value']] }
  end

  it 'adds no route parameters from a page outside the catalog' do
    get '/terms'

    expect(hidden_fields.keys).not_to include('controller', 'action')
  end

  # A nested value travels as Rails' bracket form, so the next search keeps it.
  it 'keeps a facet filter as a facet filter' do
    get '/catalog', params: { q: 'coastal', f: { human_readable_type_ssim: ['Work'] } }

    expect(hidden_fields).to eq('f[human_readable_type_ssim][]' => 'Work')
  end

  it 'sends the query once, from its box, and keeps the sort' do
    get '/catalog', params: { q: 'coastal', sort: 'title' }

    expect(hidden_fields).to eq('sort' => 'title')
    expect(response.parsed_body.css('form.search-query-form input[name=q]').size).to eq(1)
  end
end
