# frozen_string_literal: true

require 'rails_helper'

# "Why this result?". Solr is stubbed with an explanation captured from a real
# one; SearchExplanation's own spec covers the reading of it.
RSpec.describe 'SearchExplanations', type: :request do
  include Devise::Test::IntegrationHelpers

  let(:admin) { User.new(email: 'admin@example.com', nuid: '000000004', name: 'User, Admin', role: 'admin') }
  let(:delegate) do
    User.new(email: 'jane@example.com', nuid: '000000002', name: 'Doe, Jane', role: 'privileged',
             groups: [Permissions::STAFF_EDIT_GROUP, Permissions::ADMIN_GROUP])
  end
  let(:staff) do
    User.new(email: 's@example.com', nuid: '000000006', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
  end
  let(:explain) { JSON.parse(Rails.root.join('spec/fixtures/files/explain_one_word.json').read) }

  def stub_solr(documents)
    allow(Blacklight.default_index).to receive(:search)
      .and_return(instance_double(Blacklight::Solr::Response, documents: documents))
  end

  def explained = SolrDocument.new('id' => 'uuid-1', 'score' => 11.128, '[explain]' => explain)

  it 'explains a result to an admin in a sentence, then the detail' do
    sign_in admin
    stub_solr([explained])

    get search_explanation_path('uuid-1', q: 'coastal')

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('This appeared because “coastal” is in its title', 'counts most',
                                     '(stem variation)', 'A field can be listed more than once',
                                     'Where it matched', 'id="explain-modal-frame"')
    expect(response.body).not_to include('Alternative title:')
  end

  # The search reruns narrowed to this one result, so its score is the one the
  # page ranked by: a filter never changes a score.
  it 'reruns the search with the same words, narrowed to the result' do
    sign_in admin
    stub_solr([explained])

    get search_explanation_path('uuid-1', q: 'coastal')

    expect(Blacklight.default_index).to have_received(:search).with(params: satisfy { |builder|
      hash = builder.to_hash
      hash[:q] == 'coastal' && Array(hash[:fq]).include?('id:"uuid-1"') && hash[:fl].include?('[explain style=nl]')
    })
  end

  it 'lets a delegated admin ask' do
    sign_in delegate
    stub_solr([explained])

    get search_explanation_path('uuid-1', q: 'coastal')

    expect(response).to have_http_status(:ok)
  end

  it 'refuses anyone else' do
    sign_in staff
    get search_explanation_path('uuid-1', q: 'coastal')
    expect(response).to have_http_status(:forbidden)
  end

  it 'says a browse has nothing to explain, without asking Solr' do
    sign_in admin
    allow(Blacklight.default_index).to receive(:search)

    get search_explanation_path('uuid-1')

    expect(response.body).to include('no search terms')
    expect(Blacklight.default_index).not_to have_received(:search)
  end

  it 'says so when the result is not in the asker’s results' do
    sign_in admin
    stub_solr([])

    get search_explanation_path('uuid-1', q: 'coastal')

    expect(response.body).to include('This item is not in your results for')
  end

  it 'warns that a sort other than relevance set the order' do
    sign_in admin
    stub_solr([explained])

    get search_explanation_path('uuid-1', q: 'coastal', sort: 'date-added')

    expect(response.body).to include('sorted by date added')
  end
end
