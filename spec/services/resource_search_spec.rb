# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResourceSearch do
  # Plain double (see search_builder_spec): current_user isn't a verifiable
  # instance method on CatalogController.
  let(:scope) do
    double('scope',
           blacklight_config: CatalogController.blacklight_config,
           current_user:      nil)
  end

  describe '#filters' do
    it 'matches the requested container types and drops tombstoned docs' do
      filters = described_class.new(scope: scope, query: 'x').filters
      expect(filters).to include('internal_resource_tesim:(Collection OR Community)',
                                 '-tombstoned_bsi:true')
    end

    it 'narrows to a single type when asked (e.g. communities only)' do
      filters = described_class.new(scope: scope, query: 'x', types: %w[Community]).filters
      expect(filters).to include('internal_resource_tesim:(Community)')
    end

    it 'excludes the node itself (uuid) and its subtree (noid) when moving' do
      filters = described_class.new(scope: scope, query: 'x',
                                    exclude_node_uuid:    'uuid-1',
                                    exclude_subtree_noid: 'abc').filters
      expect(filters).to include('-id:"uuid-1"', '-ancestor_ids_ssim:"abc"')
    end

    it 'omits the exclusion clauses when not moving' do
      filters = described_class.new(scope: scope, query: 'x').filters
      expect(filters).not_to include(a_string_matching(/\A-id:/))
      expect(filters).not_to include(a_string_matching(/ancestor_ids_ssim/))
    end
  end

  describe '#call' do
    it 'does not query Solr (and returns empty) when the query is blank' do
      expect(Blacklight.default_index).not_to receive(:search)
      response = described_class.new(scope: scope, query: '').call
      expect(response.documents).to be_empty
    end

    it 'queries Solr with a SearchBuilder when given a query' do
      fake = Blacklight::Solr::Response.new({}, {})
      allow(Blacklight.default_index).to receive(:search).and_return(fake)

      described_class.new(scope: scope, query: 'arch').call

      expect(Blacklight.default_index).to have_received(:search).with(an_instance_of(SearchBuilder))
    end
  end
end
