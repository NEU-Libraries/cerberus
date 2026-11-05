# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkShowcase do
  let(:scope) do
    double('scope', blacklight_config: CatalogController.blacklight_config, current_user: nil)
  end
  let(:index) { instance_double(Blacklight::Solr::Repository) }
  let(:options) { { 'Datasets' => 'sc-data', 'Presentations' => 'sc-pres' } }
  let(:art_options) { { 'Datasets' => 'sc-art-data', 'Presentations' => 'sc-art-pres' } }

  def doc(noid, title: nil, parent: nil)
    SolrDocument.new('id' => "uuid-#{noid}", 'title_tsim' => [title].compact,
                     'alternate_ids_tesim' => ["id-#{noid}"], 'a_member_of_ssi' => parent)
  end

  def response(docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  # The first search finds the showcases among the linked collections, the
  # second resolves every placement's community at once.
  let(:linked_docs) { [doc('col-plain', title: 'Field Notes'), doc('sc-data', title: 'Datasets', parent: 'id-uuid-comm1')] }
  let(:community_docs) { [doc('comm1', title: 'Library')] }

  before do
    allow(AtlasRb::Work).to receive(:linked_members).with('w1').and_return(%w[col-plain sc-data])
    allow(index).to receive(:search) do |params:|
      Array(params[:fq]).any? { |fq| fq.include?('{!terms f=id}') } ? response(community_docs) : response(linked_docs)
    end
    allow(Blacklight).to receive(:default_index).and_return(index)
    allow(ShowcaseFinder).to receive(:call).with(scope: scope, community_noid: 'comm1').and_return(options)
    allow(ShowcaseFinder).to receive(:call).with(scope: scope, community_noid: 'comm2').and_return(art_options)
  end

  subject(:placements) { described_class.call(scope: scope, work_noid: 'w1') }

  it "names the Work's genre showcase, its community, and the community's other showcases" do
    placement = placements.sole
    expect(placement.showcase_noid).to eq('sc-data')
    expect(placement.genre).to eq('Datasets')
    expect(placement.community_noid).to eq('comm1')
    expect(placement.community_title).to eq('Library')
    expect(placement.options).to eq(options)
  end

  # Faculty in two departments publish one Work into both communities.
  context 'when the Work is in showcases of two communities' do
    let(:linked_docs) do
      [doc('sc-data', title: 'Datasets', parent: 'id-uuid-comm1'),
       doc('sc-art-data', title: 'Datasets', parent: 'id-uuid-comm2')]
    end
    let(:community_docs) { [doc('comm1', title: 'Library'), doc('comm2', title: 'Art')] }

    it 'returns one placement per community, each with its own options' do
      expect(placements.map(&:community_title)).to contain_exactly('Library', 'Art')
      expect(placements.to_h { |p| [p.community_noid, p.options] }).to eq('comm1' => options, 'comm2' => art_options)
    end

    it 'resolves both communities in one query' do
      community_queries = 0
      allow(index).to receive(:search) do |params:|
        next response(linked_docs) unless Array(params[:fq]).any? { |fq| fq.include?('{!terms f=id}') }

        community_queries += 1
        response(community_docs)
      end

      placements

      expect(community_queries).to eq(1)
    end
  end

  it 'searches only featured Collections among the linked ones' do
    fqs = []
    allow(index).to receive(:search) do |params:|
      fqs << Array(params[:fq])
      response([])
    end

    placements

    expect(fqs.first).to include('featured_bsi:true', '{!terms f=alternate_ids_ssim}id-col-plain,id-sc-data')
  end

  it 'answers empty for a Work linked into no collection' do
    allow(AtlasRb::Work).to receive(:linked_members).with('w1').and_return([])

    expect(placements).to eq([])
  end

  # A featured Collection that is not titled after a genre is not a showcase.
  it 'answers empty when no linked collection is a genre showcase' do
    allow(index).to receive(:search).and_return(response([doc('col-plain', title: 'Field Notes')]))

    expect(placements).to eq([])
  end
end
