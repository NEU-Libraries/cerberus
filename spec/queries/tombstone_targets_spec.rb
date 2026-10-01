# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TombstoneTargets do
  let(:targets) { described_class.new(noid: 'top', uuid: 'uuid-top') }

  before do
    allow(ContainerDescendantsQuery).to receive(:new)
      .and_return(instance_double(ContainerDescendantsQuery, subtree_fq: 'SUBTREE'))
  end

  # A community can hold communities, and an item withdrawn earlier must stay
  # off this cascade's list.
  it 'widens the narrowing walk to communities and skips what is already withdrawn' do
    expect(Blacklight.default_index).to receive(:search)
      .with(hash_including(fq: ['SUBTREE', described_class::TYPES, described_class::LIVE]))
      .and_return(instance_double(Blacklight::Solr::Response, documents: []))

    targets.to_a
  end

  it 'counts the live items beneath the container, by type, leaving the container out' do
    allow(SolrFacetValues).to receive(:call)
      .with(field:    'internal_resource_tesim',
            extra_fq: ['SUBTREE', described_class::TYPES, described_class::LIVE, '-id:"uuid-top"'])
      .and_return([['work', 412], ['collection', 3]])

    expect(targets.counts).to eq('Work' => 412, 'Collection' => 3, 'Community' => 0)
    expect(targets.total).to eq(415)
  end

  it 'is over the limit only above it' do
    allow(SolrFacetValues).to receive(:call).and_return([['work', described_class::LIMIT]])
    expect(targets.over_limit?).to be(false)

    over = described_class.new(noid: 'top', uuid: 'uuid-top')
    allow(SolrFacetValues).to receive(:call).and_return([['work', described_class::LIMIT + 1]])
    expect(over.over_limit?).to be(true)
  end
end
