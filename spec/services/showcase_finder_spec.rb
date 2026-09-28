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

  let(:index) { instance_double(Blacklight::Solr::Repository) }
  let(:showcases) do
    # Two real genres + one off-vocabulary title that must be ignored.
    [showcase_doc('Datasets', 'aaa'), showcase_doc('Presentations', 'bbb'), showcase_doc('Staff Picks', 'ccc')]
  end

  def response(docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  # One entry per search: the first resolves the community's uuid, the second
  # finds its showcases.
  let(:searched_fqs) { [] }

  before do
    allow(index).to receive(:search) do |params:|
      searched_fqs << Array(params[:fq])
      if Array(params[:fq]).any? { |fq| fq.include?('alternate_ids_ssim') }
        response([SolrDocument.new('id' => 'comm1-uuid')])
      else
        response(showcases)
      end
    end
    allow(Blacklight).to receive(:default_index).and_return(index)
  end

  # A descendant community's showcases carry the same genre titles, so matching
  # the whole subtree let the root resolve a genre to a sub-community's showcase.
  describe 'the membership filter' do
    it 'matches only the direct children of the community' do
      described_class.call(scope: scope, community_noid: 'comm1')

      showcase_fqs = searched_fqs.last
      expect(showcase_fqs).to include(MembershipQuery.members_fq(['comm1-uuid']))
      expect(showcase_fqs.join).not_to include(MembershipQuery::ANCESTOR_FIELD)
    end

    it 'resolves the community by its noid' do
      described_class.call(scope: scope, community_noid: 'comm1')

      expect(searched_fqs.first).to include('{!terms f=alternate_ids_ssim}id-comm1')
    end

    it 'returns {} when the community does not resolve' do
      allow(index).to receive(:search).and_return(response([]))

      expect(described_class.call(scope: scope, community_noid: 'gone')).to eq({})
    end
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
