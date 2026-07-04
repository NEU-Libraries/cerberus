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
end
