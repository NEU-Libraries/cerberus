# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FeaturedCategory do
  let(:scope) do
    double('scope', blacklight_config: CatalogController.blacklight_config, current_user: nil)
  end

  def showcase_doc(title, uuid)
    SolrDocument.new('id' => uuid, 'title_tsim' => [title], 'featured_bsi' => true)
  end

  it 'returns an empty response for a blank label without querying' do
    expect(Blacklight).not_to receive(:default_index)
    expect(described_class.call(scope: scope, label: '').documents).to be_empty
  end

  it 'returns an empty response when no showcase matches the label' do
    showcase_resp = instance_double(Blacklight::Solr::Response, documents: [])
    index = instance_double(Blacklight::Solr::Repository)
    allow(index).to receive(:search).and_return(showcase_resp)
    allow(Blacklight).to receive(:default_index).and_return(index)

    expect(described_class.call(scope: scope, label: 'Datasets').documents).to be_empty
  end

  it 'queries works that are members of the exactly-titled featured showcases' do
    # First search → showcases (one exact "Datasets", one over-matched phrase
    # that must be filtered out by the Ruby exact-match); second → the works.
    showcase_resp = instance_double(Blacklight::Solr::Response,
                                    documents: [showcase_doc('Datasets', 'uuid-ds'),
                                                showcase_doc('Datasets Annual', 'uuid-other')])
    works_resp = instance_double(Blacklight::Solr::Response, documents: [SolrDocument.new('id' => 'w1')])
    index = instance_double(Blacklight::Solr::Repository)
    allow(index).to receive(:search).and_return(showcase_resp, works_resp)
    allow(Blacklight).to receive(:default_index).and_return(index)

    # The members fq must target only the exact-title showcase (uuid-ds), not the
    # over-matched "Datasets Annual".
    expect(MembershipQuery).to receive(:members_fq).with(['uuid-ds'], include_linked: true).and_call_original

    result = described_class.call(scope: scope, label: 'Datasets')

    expect(result.documents.pluck('id')).to eq(['w1'])
  end
end
