# frozen_string_literal: true

require 'rails_helper'

# Real Works in Atlas and Solr, because the point is the gate: a stubbed Solr
# would prove only that the code calls the method it calls.
RSpec.describe WorkAbstracts do
  before(:all) do
    community = AtlasRb::Community.create(nil, mods('community'), nuid: admin)
    AtlasRb::Resource.set_permissions(community.id, read_public, nuid: admin)
    collection = AtlasRb::Collection.create(community.id, mods('collection'), nuid: admin)
    AtlasRb::Resource.set_permissions(collection.id, read_public, nuid: admin)
    @public     = work(collection.id, read_public)
    @restricted = work(collection.id, 'read' => ['northeastern:drs:repository:staff'])
  end

  def admin = '000000004'
  def mods(kind) = Rails.root.join('spec/fixtures/files', "#{kind}-mods.xml").to_s
  def read_public = { 'read' => ['public'] }

  def work(parent_id, acl)
    work = AtlasRb::Work.create(parent_id, mods('work'), nuid: admin)
    AtlasRb::Work.complete(work.id, nuid: admin)
    AtlasRb::Resource.set_permissions(work.id, acl, nuid: admin)
    work
  end

  let(:user) { nil }
  let(:scope) do
    GatedSearchService.new(config:       CatalogController.blacklight_config,
                           search_state: Blacklight::SearchState.new({}, CatalogController.blacklight_config),
                           current_user: user)
  end

  it 'reads each discoverable Work’s abstract by noid' do
    abstracts = described_class.call(scope: scope, noids: [@public.id])

    expect(abstracts.fetch(@public.id)).to start_with('How do people and cities respond')
  end

  it 'leaves out a Work the viewer may not discover, and an unknown noid' do
    abstracts = described_class.call(scope: scope, noids: [@public.id, @restricted.id, 'neverexisted'])

    expect(abstracts.keys).to eq([@public.id])
  end

  it 'answers an empty list without a query' do
    expect(Blacklight.default_index).not_to receive(:search)

    expect(described_class.call(scope: scope, noids: [])).to eq({})
  end
end
