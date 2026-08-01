# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NarrowingTargets do
  def doc(noid:, klass:, ancestors: [])
    instance_double(SolrDocument).tap do |d|
      allow(d).to receive(:[]).with('alternate_ids_ssim').and_return(["id-#{noid}"])
      allow(d).to receive(:[]).with('internal_resource_tesim').and_return([klass])
      allow(d).to receive(:[]).with(MembershipQuery::ANCESTOR_FIELD).and_return(ancestors)
    end
  end

  # Two Solr calls: ContainerDescendantsQuery resolving descendant containers to
  # build the subtree fq, then this class's own projection.
  def stub_solr(*docs)
    containers = instance_double(Blacklight::Solr::Response, documents: [])
    targets    = instance_double(Blacklight::Solr::Response, documents: docs)
    allow(Blacklight.default_index).to receive(:search).and_return(containers, targets)
  end

  let(:targets) { described_class.new(noid: 'top', uuid: 'uuid-top') }

  # The container is the ancestor of everything else in its own subtree, so it
  # necessarily has the shallowest depth and falls out last without a special
  # case. Works rank ahead of every container because they are leaves.
  it 'orders deepest first, with the container itself last' do
    stub_solr(
      doc(noid: 'top',   klass: 'Collection', ancestors: %w[community]),
      doc(noid: 'child', klass: 'Collection', ancestors: %w[community top]),
      doc(noid: 'grand', klass: 'Collection', ancestors: %w[community top child]),
      doc(noid: 'work',  klass: 'Work')
    )

    expect(targets.map(&:noid)).to eq(%w[work grand child top])
  end

  it 'ranks every Work ahead of every container' do
    stub_solr(
      doc(noid: 'deep', klass: 'Collection', ancestors: %w[a b c d e]),
      doc(noid: 'w',    klass: 'Work')
    )

    expect(targets.first.noid).to eq('w')
    expect(targets.first.depth).to eq(described_class::LEAF_DEPTH)
  end

  it 'exposes the atlas_rb class that owns each noid' do
    stub_solr(doc(noid: 'w', klass: 'Work'), doc(noid: 'top', klass: 'Collection'))

    expect(targets.map(&:atlas_class)).to eq([AtlasRb::Work, AtlasRb::Collection])
  end

  it 'skips a document carrying neither a noid nor a type' do
    blank = instance_double(SolrDocument)
    allow(blank).to receive(:[]).and_return(nil)
    stub_solr(blank, doc(noid: 'top', klass: 'Collection'))

    expect(targets.map(&:noid)).to eq(['top'])
  end

  it 'restricts the projection to resources with their own ACL' do
    stub_solr

    targets.to_a

    expect(Blacklight.default_index).to have_received(:search).with(
      hash_including(fq: array_including(described_class::AFFECTED_TYPES))
    )
  end
end
