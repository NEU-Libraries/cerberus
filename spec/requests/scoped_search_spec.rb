# frozen_string_literal: true

require 'rails_helper'

# The search box on a container page and on the People lists. It carries the
# page's search state into the next search, as the header form does.
RSpec.describe 'The scoped search form', type: :request do
  def hidden_fields
    form = response.parsed_body.at_css('form.scoped-search')
    form.css('input[type=hidden]').to_h { |input| [input['name'], input['value']] }
  end

  # The People list scopes itself with a Type facet, so a search from its box
  # must keep it, or works and collections come back too.
  # A query, so the box shows even when the test index holds no Person.
  it 'keeps a facet filter as a facet filter' do
    get '/people', params: { q: 'anyone' }

    expect(hidden_fields).to include('f[type_ssim][]' => 'Person')
    expect(hidden_fields.keys).not_to include('f', 'controller', 'action')
  end
end
