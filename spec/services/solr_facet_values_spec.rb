# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SolrFacetValues do
  it 'unpacks the raw Solr facet_fields flat array into [value, count] pairs' do
    response = instance_double(Blacklight::Solr::Response,
                               facet_fields: { 'classification_ssim' => ['Image', 12, 'Text', 3] })
    expect(Blacklight.default_index).to receive(:search)
      .with(hash_including('facet.field' => 'classification_ssim'))
      .and_return(response)

    expect(described_class.call(field: 'classification_ssim')).to eq([['Image', 12], ['Text', 3]])
  end

  it 'returns an empty array when the field has no facet data' do
    response = instance_double(Blacklight::Solr::Response, facet_fields: {})
    allow(Blacklight.default_index).to receive(:search).and_return(response)

    expect(described_class.call(field: 'classification_ssim')).to eq([])
  end
end
