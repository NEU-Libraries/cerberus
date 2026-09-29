# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StructuralParents do
  let(:index) { instance_double(Blacklight::Solr::Repository) }

  def doc(id, parent: nil, title: nil, tombstoned: nil)
    SolrDocument.new('id' => id, 'a_member_of_ssi' => parent, 'title_tsim' => [title].compact,
                     'tombstoned_bsi' => tombstoned)
  end

  def response(docs)
    instance_double(Blacklight::Solr::Response, documents: docs)
  end

  before { allow(Blacklight).to receive(:default_index).and_return(index) }

  it "reads every row's parent in one query, keyed by uuid" do
    allow(index).to receive(:search).and_return(response([doc('p1', title: 'Parent One'), doc('p2')]))

    parents = described_class.call(documents: [doc('a', parent: 'id-p1'), doc('b', parent: 'id-p2'),
                                               doc('c', parent: 'id-p1')])

    expect(parents.keys).to contain_exactly('p1', 'p2')
    expect(index).to have_received(:search).once
                                           .with(hash_including(fq: [MembershipQuery.identity_fq(%w[p1 p2])], rows: 2))
  end

  # The catalog's default fq drops tombstoned documents; a tombstoned parent is
  # the one that has to be restored first.
  it 'does not filter out tombstoned parents' do
    allow(index).to receive(:search).and_return(response([]))

    described_class.call(documents: [doc('a', parent: 'id-p1')])

    expect(index).to have_received(:search) do |params|
      expect(Array(params[:fq]).join).not_to include('tombstoned')
    end
  end

  # A stub document names its own fields, so only the request shows this.
  it 'fetches the field the parent link reads its noid from' do
    allow(index).to receive(:search).and_return(response([]))

    described_class.call(documents: [doc('a', parent: 'id-p1')])

    expect(index).to have_received(:search).with(hash_including(fl: a_string_including('alternate_ids_tesim')))
  end

  it 'asks nothing for rows with no parent' do
    allow(index).to receive(:search)

    expect(described_class.call(documents: [doc('root')])).to eq({})
    expect(index).not_to have_received(:search)
  end

  it 'reads a failed query as no parents, so the registry still renders' do
    allow(index).to receive(:search).and_raise(Blacklight::Exceptions::InvalidRequest)

    expect(described_class.call(documents: [doc('a', parent: 'id-p1')])).to eq({})
  end
end
