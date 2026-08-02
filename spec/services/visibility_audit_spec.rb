# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VisibilityAudit do
  def container(uuid:, noid:, read:, **opts)
    parent = opts[:parent]
    doc(id: uuid, 'alternate_ids_ssim' => ["id-#{noid}"], 'title_tsim' => [opts.fetch(:title, 'A container')],
        'internal_resource_tesim' => [opts.fetch(:klass, 'Collection')], 'read_access_group_ssim' => read,
        'a_member_of_ssi' => parent && "id-#{parent}")
  end

  def work(noid:, read:, parent:)
    doc('alternate_ids_ssim' => ["id-#{noid}"], 'read_access_group_ssim' => read,
        'a_member_of_ssi' => "id-#{parent}")
  end

  def doc(fields)
    id = fields.delete(:id)
    instance_double(SolrDocument, id: id).tap do |d|
      allow(d).to receive(:[]) { |key| fields[key] }
    end
  end

  # The service pages each type until a batch comes back empty, so every scan
  # needs its page followed by a terminator.
  def stub_scan(containers: [], works: [])
    allow(Blacklight.default_index).to receive(:search).and_return(
      instance_double(Blacklight::Solr::Response, documents: containers),
      instance_double(Blacklight::Solr::Response, documents: []),
      instance_double(Blacklight::Solr::Response, documents: works),
      instance_double(Blacklight::Solr::Response, documents: [])
    )
  end

  it 'reports nothing when every child is within its container' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'c1', read: ['public'])],
              works:      [work(noid: 'w1', read: ['public'], parent: 'u1')])

    expect(described_class.new.call).to be_empty
  end

  it 'reports a public work inside a restricted collection' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'c1', read: ['archives'], title: 'Reading Room')],
              works:      [work(noid: 'w1', read: ['public'], parent: 'u1')])

    violations = described_class.new.call

    expect(violations.length).to eq(1)
    expect(violations.first).to have_attributes(noid: 'w1', klass: 'Work', parent_noid: 'c1')
    expect(violations.first).to be_public
    expect(violations.first.to_s).to include('Work w1 [public]', 'Reading Room', '[archives]')
  end

  it 'reports a group the container does not grant' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'c1', read: ['archives'])],
              works:      [work(noid: 'w1', read: ['nupd'], parent: 'u1')])

    violation = described_class.new.call.first

    expect(violation.noid).to eq('w1')
    expect(violation).not_to be_public
  end

  it 'accepts a child narrower than its container' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'c1', read: %w[archives nupd])],
              works:      [work(noid: 'w1', read: ['archives'], parent: 'u1')])

    expect(described_class.new.call).to be_empty
  end

  # Nested containers are checked against each other from the same scan, with no
  # second pass: every pair holding is the same as the whole chain holding.
  it 'reports a collection more visible than its own parent' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'top', read: ['archives'], klass: 'Community'),
                           container(uuid: 'u2', noid: 'child', read: ['public'], parent: 'u1')])

    violations = described_class.new.call

    expect(violations.map(&:noid)).to eq(['child'])
    expect(violations.first.klass).to eq('Collection')
  end

  it 'labels a sub-community as a Community, not a Collection' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'top', read: ['archives'], klass: 'Community'),
                           container(uuid: 'u2', noid: 'sub', read: ['public'], parent: 'u1', klass: 'Community')])

    expect(described_class.new.call.first.klass).to eq('Community')
  end

  # Atlas mints personal roots public deliberately, because the private People
  # community they sit in would otherwise 403 an owner out of their own
  # workspace. One per account, all expected — reporting them would bury the
  # real findings.
  it 'ignores a personal root, which is public inside People by design' do
    root = container(uuid: 'u2', noid: 'root', read: ['public'], parent: 'u1', title: 'Personal Root')
    allow(root).to receive(:[]).with('personal_root_bsi').and_return(true)
    stub_scan(containers: [container(uuid: 'u1', noid: 'people', read: [], klass: 'Community'), root])

    expect(described_class.new.call).to be_empty
  end

  it 'still reports an ordinary public collection in the same private container' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'people', read: [], klass: 'Community'),
                           container(uuid: 'u2', noid: 'ordinary', read: ['public'], parent: 'u1')])

    expect(described_class.new.call.map(&:noid)).to eq(['ordinary'])
  end

  it 'leaves a root container alone — it has nothing to be contained by' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'top', read: ['public'], klass: 'Community')])

    expect(described_class.new.call).to be_empty
  end

  # A work whose parent is missing from the index cannot be judged, and guessing
  # would put noise in a report whose whole value is that every line is real.
  it 'skips a resource whose container is not indexed' do
    stub_scan(containers: [], works: [work(noid: 'orphan', read: ['public'], parent: 'gone')])

    expect(described_class.new.call).to be_empty
  end

  it 'puts public leaks ahead of group mismatches' do
    stub_scan(containers: [container(uuid: 'u1', noid: 'c1', read: ['archives'])],
              works:      [work(noid: 'mismatch', read: ['nupd'], parent: 'u1'),
                           work(noid: 'leak', read: ['public'], parent: 'u1')])

    expect(described_class.new.call.map(&:noid)).to eq(%w[leak mismatch])
  end
end
