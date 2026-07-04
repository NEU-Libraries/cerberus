# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContainerDescendantsQuery do
  it 'unions the container noid, descendant containers, and member works' do
    sub  = instance_double(SolrDocument, id: 'uuid-sub')
    work = instance_double(SolrDocument, id: 'uuid-w')
    allow(sub).to receive(:[]).with('alternate_ids_ssim').and_return(['id-sub'])
    allow(work).to receive(:[]).with('alternate_ids_ssim').and_return(['id-w'])

    # First Solr call resolves descendant containers; second resolves member works.
    allow(Blacklight.default_index).to receive(:search).and_return(
      instance_double(Blacklight::Solr::Response, documents: [sub]),
      instance_double(Blacklight::Solr::Response, documents: [work])
    )

    result = described_class.new(noid: 'c1', uuid: 'uuid-c1').noids

    expect(result).to contain_exactly('c1', 'sub', 'w')
  end

  it 'returns just the container when it has no descendants' do
    allow(Blacklight.default_index).to receive(:search)
      .and_return(instance_double(Blacklight::Solr::Response, documents: []))

    expect(described_class.new(noid: 'c1', uuid: 'uuid-c1').noids).to eq(['c1'])
  end
end
