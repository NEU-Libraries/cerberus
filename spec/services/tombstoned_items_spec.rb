# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TombstonedItems do
  # Plain double (see resource_search_spec / search_builder_spec): current_user
  # isn't a verifiable instance method on the controller scope.
  let(:scope) do
    double('scope',
           blacklight_config: CatalogController.blacklight_config,
           current_user:      nil)
  end

  describe TombstonedSearchBuilder do
    subject(:builder) { described_class.new(scope) }

    it 'inverts the catalog default: drops the exclusion, adds the inclusion' do
      params = { fq: ['-internal_resource_tesim:FileSet', '-tombstoned_bsi:true'] }
      builder.only_tombstoned(params)

      expect(params[:fq]).to include('tombstoned_bsi:true')
      expect(params[:fq]).not_to include('-tombstoned_bsi:true')
    end

    it 'leaves the other default exclusions (FileSet/Blob/Delegate) intact' do
      params = { fq: ['-internal_resource_tesim:FileSet', '-internal_resource_tesim:Blob', '-tombstoned_bsi:true'] }
      builder.only_tombstoned(params)

      expect(params[:fq]).to include('-internal_resource_tesim:FileSet', '-internal_resource_tesim:Blob')
    end

    it 'still adds the inclusion when no exclusion was present' do
      params = { fq: [] }
      builder.only_tombstoned(params)

      expect(params[:fq]).to eq(['tombstoned_bsi:true'])
    end
  end

  describe '#call' do
    it 'searches Solr through a TombstonedSearchBuilder' do
      fake = Blacklight::Solr::Response.new({}, {})
      allow(Blacklight.default_index).to receive(:search).and_return(fake)

      described_class.call(scope: scope)

      expect(Blacklight.default_index).to have_received(:search).with(params: an_instance_of(TombstonedSearchBuilder))
    end

    def docs_response(*docs)
      Blacklight::Solr::Response.new({ 'response' => { 'docs' => docs } }, {},
                                     blacklight_config: CatalogController.blacklight_config)
    end

    def doc(uuid, type = 'Work')
      { 'id' => uuid, 'internal_resource_tesim' => [type], 'alternate_ids_ssim' => ["id-noid-#{uuid}"] }
    end

    # The listing goes through a TombstonedSearchBuilder; the descendant reads
    # go to Solr directly. Each of those returns the next of `walk`.
    def searched_builder(matches: [], walk: [], **)
      captured = nil
      allow(Blacklight.default_index).to receive(:search) do |params: nil, **kwargs|
        if params.nil?
          @walked = (@walked || []) << kwargs
          next docs_response(*walk.shift)
        end
        next docs_response(*matches) if params.to_hash['fl'] == 'id,internal_resource_tesim,alternate_ids_ssim'

        captured = params
        docs_response
      end
      described_class.call(scope: scope, **)
      captured
    end

    it 'lists everything, most recently withdrawn first, with no query' do
      builder = searched_builder

      expect(builder.blacklight_params[:q]).to eq('*:*')
      expect(builder.to_hash['sort']).to eq('tombstoned_at_dtsi desc')
    end

    # v1 holds 8,000+ tombstoned items, so the registry has to be searchable.
    it 'searches by the query, ranked by relevance, when nothing it matched holds members' do
      builder = searched_builder(query: '  Withdrawn thesis ', matches: [doc('uuid-w1')])

      expect(builder.blacklight_params[:q]).to eq('Withdrawn thesis')
      expect(builder.to_hash['sort']).not_to eq('tombstoned_at_dtsi desc')
      expect(@walked).to be_nil
    end

    # Purging a container means purging what it holds first, so a search that
    # finds one lists its tombstoned descendants beside it. Only containers carry
    # the ancestor field, so the nested containers come first, then the members
    # of every container.
    it "lists a matched container's tombstoned descendants in two reads" do
      builder = searched_builder(query: 'papers', matches: [doc('uuid-c1', 'Collection'), doc('uuid-w0')],
                                 walk: [[doc('uuid-c2', 'Collection')], [doc('uuid-c2', 'Collection'), doc('uuid-w1')]])

      expect(@walked.map { |call| call[:fq].last })
        .to eq(['{!terms f=ancestor_ids_ssim}noid-uuid-c1', '{!terms f=a_member_of_ssi}id-uuid-c1,id-uuid-c2'])
      expect(@walked).to all(include(fq: include('tombstoned_bsi:true', described_class::TYPE_FILTER)))
      expect(builder.blacklight_params[:q]).to eq('*:*')
      expect(builder.to_hash['fq']).to include('{!terms f=id}uuid-c1,uuid-w0,uuid-c2,uuid-w1')
      expect(builder.to_hash['sort']).to eq('tombstoned_at_dtsi desc')
    end

    it 'takes the page size from the allowed options and ignores any other' do
      expect(searched_builder(per_page: '20').to_hash['rows']).to eq(20)
      expect(searched_builder(per_page: '7').to_hash['rows']).to eq(described_class::DEFAULT_PER_PAGE)
    end

    # Whole UTC days, with the end date made inclusive by stopping before the
    # next day.
    it 'filters by withdrawal date, inclusive at both ends' do
      builder = searched_builder(from: Date.new(2026, 10, 1), to: Date.new(2026, 10, 7))

      expect(builder.to_hash['fq'])
        .to include('tombstoned_at_dtsi:[2026-10-01T00:00:00Z TO 2026-10-08T00:00:00Z}')
    end

    it 'leaves an open end of the date range unbounded' do
      expect(searched_builder(from: Date.new(2026, 10, 1)).to_hash['fq'])
        .to include('tombstoned_at_dtsi:[2026-10-01T00:00:00Z TO *}')
      expect(searched_builder(to: Date.new(2026, 10, 7)).to_hash['fq'])
        .to include('tombstoned_at_dtsi:[* TO 2026-10-08T00:00:00Z}')
    end
  end
end
