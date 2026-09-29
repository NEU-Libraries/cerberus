# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WorkShowcase do
  let(:scope) do
    double('scope', blacklight_config: CatalogController.blacklight_config, current_user: nil)
  end
  let(:index) { instance_double(Blacklight::Solr::Repository) }
  let(:options) { { 'Datasets' => 'sc-data', 'Presentations' => 'sc-pres' } }

  def doc(noid, title: nil, parent: nil)
    SolrDocument.new('id' => "uuid-#{noid}", 'title_tsim' => [title].compact,
                     'alternate_ids_tesim' => ["id-#{noid}"], 'a_member_of_ssi' => parent)
  end

  def response(docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  # The first search finds the showcase among the linked collections, the second
  # resolves its parent community.
  let(:linked_docs) { [doc('col-plain', title: 'Field Notes'), doc('sc-data', title: 'Datasets', parent: 'id-comm-uuid')] }

  before do
    allow(AtlasRb::Work).to receive(:linked_members).with('w1').and_return(%w[col-plain sc-data])
    allow(index).to receive(:search) do |params:|
      Array(params[:fq]).any? { |fq| fq.include?('{!terms f=id}') } ? response([doc('comm1', title: 'Library')]) : response(linked_docs)
    end
    allow(Blacklight).to receive(:default_index).and_return(index)
    allow(ShowcaseFinder).to receive(:call).with(scope: scope, community_noid: 'comm1').and_return(options)
  end

  subject(:placement) { described_class.call(scope: scope, work_noid: 'w1') }

  it "names the Work's genre showcase, its community, and the community's other showcases" do
    expect(placement.showcase_noid).to eq('sc-data')
    expect(placement.genre).to eq('Datasets')
    expect(placement.community_noid).to eq('comm1')
    expect(placement.community_title).to eq('Library')
    expect(placement.options).to eq(options)
  end

  it 'searches only featured Collections among the linked ones' do
    fqs = []
    allow(index).to receive(:search) do |params:|
      fqs << Array(params[:fq])
      response([])
    end

    placement

    expect(fqs.first).to include('featured_bsi:true', '{!terms f=alternate_ids_ssim}id-col-plain,id-sc-data')
  end

  it 'answers nil for a Work linked into no collection' do
    allow(AtlasRb::Work).to receive(:linked_members).with('w1').and_return([])

    expect(placement).to be_nil
  end

  # A featured Collection that is not titled after a genre is not a showcase.
  it 'answers nil when no linked collection is a genre showcase' do
    allow(index).to receive(:search).and_return(response([doc('col-plain', title: 'Field Notes')]))

    expect(placement).to be_nil
  end
end
