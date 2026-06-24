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

      expect(Blacklight.default_index).to have_received(:search).with(an_instance_of(TombstonedSearchBuilder))
    end
  end
end
