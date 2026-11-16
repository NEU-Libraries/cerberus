# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RollupContainerImpressionsJob do
  let(:today) { Date.current }

  it 'sums leaf human counts over a container descendant set' do
    # One container c1 enumerated from Solr; its descendant set resolves to two
    # Works (the Solr derive-down is unit-specced separately).
    container_doc = instance_double(SolrDocument, id: 'uuid-c1')
    allow(container_doc).to receive(:[]).with('alternate_ids_ssim').and_return(['id-c1'])
    allow(Blacklight.default_index).to receive(:search)
      .and_return(instance_double(Blacklight::Solr::Response, documents: [container_doc]))
    allow(ContainerDescendantsQuery).to receive(:new).with(noid: 'c1', uuid: 'uuid-c1')
                                                     .and_return(instance_double(ContainerDescendantsQuery, noids: %w[c1 w1 w2]))

    ImpressionDailyCount.create!(noid: 'w1', action: 'view',     day: today, count: 5)
    ImpressionDailyCount.create!(noid: 'w2', action: 'view',     day: today, count: 3)
    ImpressionDailyCount.create!(noid: 'w1', action: 'download', day: today, count: 2)

    described_class.perform_now

    expect(ImpressionContainerDailyCount.find_by(noid: 'c1', action: 'view', day: today)[:count]).to eq(8)
    expect(ImpressionContainerDailyCount.find_by(noid: 'c1', action: 'download', day: today)[:count]).to eq(2)
  end

  it 'clears totals for a container with no leaf traffic and for one gone from Solr' do
    container_doc = instance_double(SolrDocument, id: 'uuid-c2')
    allow(container_doc).to receive(:[]).with('alternate_ids_ssim').and_return(['id-c2'])
    allow(Blacklight.default_index).to receive(:search)
      .and_return(instance_double(Blacklight::Solr::Response, documents: [container_doc]))
    allow(ContainerDescendantsQuery).to receive(:new).with(noid: 'c2', uuid: 'uuid-c2')
                                                     .and_return(instance_double(ContainerDescendantsQuery, noids: %w[c2 w7]))

    ImpressionContainerDailyCount.create!(noid: 'c2',     action: 'view', day: today, count: 4)
    ImpressionContainerDailyCount.create!(noid: 'c-gone', action: 'view', day: today, count: 9)

    described_class.perform_now

    expect(ImpressionContainerDailyCount.where(noid: %w[c2 c-gone])).to be_empty
  end
end
