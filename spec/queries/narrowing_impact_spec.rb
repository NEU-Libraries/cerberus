# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NarrowingImpact do
  # Two Solr calls, in order: ContainerDescendantsQuery resolving descendant
  # containers (to build the subtree fq), then this class's rows:0 facet query.
  def stub_solr(descendants: [], total: 0, depositors: {})
    containers = instance_double(Blacklight::Solr::Response, documents: descendants)
    facets     = instance_double(Blacklight::Solr::Response, total: total)
    allow(facets).to receive(:dig).with('facet_counts', 'facet_fields', described_class::DEPOSITOR_FIELD)
                                  .and_return(depositors.flat_map { |nuid, hits| [nuid, hits] })
    allow(Blacklight.default_index).to receive(:search).and_return(containers, facets)
  end

  # Memoized: the two stubbed Solr responses are consumed in order, so a fresh
  # instance per call would hand the facet response to the descendant lookup.
  let(:impact) { described_class.new(noid: 'c1', uuid: 'uuid-c1') }

  describe '#count and #depositors' do
    it 'reports the affected descendants and how they are attributed' do
      stub_solr(total: 7, depositors: { '000000010' => 5, '000000011' => 2 })

      expect(impact.count).to eq(7)
      expect(impact.depositors).to eq('000000010' => 5, '000000011' => 2)
    end

    it 'reports zero for a container with nothing beneath it' do
      stub_solr(total: 0)

      expect(impact.count).to eq(0)
    end
  end

  describe '#wholly_owned_by?' do
    it 'is true when every affected descendant carries that one depositor' do
      stub_solr(total: 4, depositors: { '000000010' => 4 })

      expect(impact).to be_wholly_owned_by('000000010')
    end

    it 'is false when another depositor also holds material in the subtree' do
      stub_solr(total: 4, depositors: { '000000010' => 3, '000000011' => 1 })

      expect(impact).not_to be_wholly_owned_by('000000010')
    end

    it 'is false when the sole depositor is somebody else' do
      stub_solr(total: 4, depositors: { '000000011' => 4 })

      expect(impact).not_to be_wholly_owned_by('000000010')
    end

    # The case facet keys alone cannot see: a resource indexed with no depositor
    # never appears in the facet, so the keys look unanimous while some of the
    # subtree is in fact unattributed. Only the totals disagree.
    it 'is false when part of the subtree carries no depositor at all' do
      stub_solr(total: 6, depositors: { '000000010' => 4 })

      expect(impact).not_to be_wholly_owned_by('000000010')
    end

    it 'is true for an empty container — there is nothing to own' do
      stub_solr(total: 0)

      expect(impact).to be_wholly_owned_by('000000010')
    end

    it 'is false for a caller with no NUID' do
      stub_solr(total: 2, depositors: { '000000010' => 2 })

      expect(impact).not_to be_wholly_owned_by(nil)
    end
  end

  describe '#over_cap?' do
    it 'is false at the limit' do
      stub_solr(total: described_class::CASCADE_LIMIT)

      expect(impact).not_to be_over_cap
    end

    it 'is true beyond it' do
      stub_solr(total: described_class::CASCADE_LIMIT + 1)

      expect(impact).to be_over_cap
    end
  end

  describe 'the query it issues' do
    # FileSets are deliberately outside the type restriction: a metadata FileSet
    # carries no depositor and no visibility of its own, so counting one would
    # both overstate the impact and make the ownership test unanswerable.
    it 'counts without fetching rows, restricted to resources with their own ACL' do
      stub_solr(total: 0)

      impact.count

      expect(Blacklight.default_index).to have_received(:search).with(
        hash_including(rows: 0, facet: true, 'facet.field': described_class::DEPOSITOR_FIELD,
                       fq: array_including(described_class::AFFECTED_TYPES))
      )
    end

    it 'subtracts the container itself from its own impact' do
      stub_solr(total: 0)

      impact.count

      expect(Blacklight.default_index).to have_received(:search).with(
        hash_including(fq: array_including(a_string_matching(/must_not/)))
      )
    end
  end
end
