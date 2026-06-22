# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShowcaseFinder do
  # Plain double (see resource_search_spec / search_builder_spec): current_user
  # isn't a verifiable instance method on CatalogController.
  let(:scope) do
    double('scope', blacklight_config: CatalogController.blacklight_config, current_user: nil)
  end

  def showcase_doc(title, noid)
    SolrDocument.new('id' => "uuid-#{noid}", 'title_tsim' => [title],
                     'alternate_ids_tesim' => ["id-#{noid}"], 'featured_bsi' => true)
  end

  before do
    # Two real genres + one off-vocabulary title that must be ignored.
    response = instance_double(Blacklight::Solr::Response,
                               documents: [showcase_doc('Datasets', 'aaa'),
                                           showcase_doc('Presentations', 'bbb'),
                                           showcase_doc('Staff Picks', 'ccc')])
    index = instance_double(Blacklight::Solr::Repository)
    allow(index).to receive(:search).and_return(response)
    allow(Blacklight).to receive(:default_index).and_return(index)
  end

  describe '.call without a genre_label' do
    it 'maps known genre labels to their showcase NOIDs' do
      expect(described_class.call(scope: scope, community_noid: 'comm1'))
        .to eq('Datasets' => 'aaa', 'Presentations' => 'bbb')
    end

    it 'ignores featured collections whose title is not a known genre' do
      expect(described_class.call(scope: scope, community_noid: 'comm1')).not_to have_key('Staff Picks')
    end

    it 'returns {} for a blank community' do
      expect(described_class.call(scope: scope, community_noid: '')).to eq({})
    end
  end

  describe '.call with a genre_label' do
    it 'returns the single showcase NOID for that genre' do
      expect(described_class.call(scope: scope, community_noid: 'comm1', genre_label: 'Datasets')).to eq('aaa')
    end

    it 'returns nil when no showcase exists for the genre' do
      expect(described_class.call(scope: scope, community_noid: 'comm1', genre_label: 'Monographs')).to be_nil
    end

    it 'returns nil for a blank community' do
      expect(described_class.call(scope: scope, community_noid: nil, genre_label: 'Datasets')).to be_nil
    end
  end
end
