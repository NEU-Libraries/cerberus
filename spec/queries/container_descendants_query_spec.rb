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

  describe '#container_noids and #work_noids' do
    it 'splits the container-only and work-only noids, sharing one descendant-container Solr call' do
      sub  = instance_double(SolrDocument, id: 'uuid-sub')
      work = instance_double(SolrDocument, id: 'uuid-w')
      allow(sub).to receive(:[]).with('alternate_ids_ssim').and_return(['id-sub'])
      allow(work).to receive(:[]).with('alternate_ids_ssim').and_return(['id-w'])

      expect(Blacklight.default_index).to receive(:search).once.and_return(
        instance_double(Blacklight::Solr::Response, documents: [sub])
      )
      expect(Blacklight.default_index).to receive(:search).once.and_return(
        instance_double(Blacklight::Solr::Response, documents: [work])
      )

      query = described_class.new(noid: 'c1', uuid: 'uuid-c1')

      expect(query.container_noids).to contain_exactly('c1', 'sub')
      expect(query.work_noids).to contain_exactly('w')
      # A third call (#noids) would raise on the mocked expectations above if
      # the descendant-container lookup weren't memoized.
      expect(query.noids).to contain_exactly('c1', 'sub', 'w')
    end
  end

  describe '#container_uuids and #subtree_fq' do
    it 'lists its own uuid plus every descendant container uuid' do
      sub = instance_double(SolrDocument, id: 'uuid-sub')
      allow(Blacklight.default_index).to receive(:search)
        .and_return(instance_double(Blacklight::Solr::Response, documents: [sub]))

      expect(described_class.new(noid: 'c1', uuid: 'uuid-c1').container_uuids)
        .to contain_exactly('uuid-c1', 'uuid-sub')
    end

    it 'builds an fq ORing self-or-descendant-container identity with structural membership of that set' do
      allow(Blacklight.default_index).to receive(:search)
        .and_return(instance_double(Blacklight::Solr::Response, documents: []))

      fq = described_class.new(noid: 'c1', uuid: 'uuid-c1').subtree_fq

      expect(fq).to include('{!terms f=id}uuid-c1')
      expect(fq).to include('{!terms f=a_member_of_ssi}id-uuid-c1')
      expect(fq).not_to include('a_linked_member_of_ssim') # structural only, no linked overlay
    end
  end
end
