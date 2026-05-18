# frozen_string_literal: true

require 'rails_helper'

describe Transformable do
  let(:host_class) do
    Class.new do
      include Transformable

      attr_accessor :params, :current_user

      # The concern leans on these helpers, which live on
      # ApplicationController / Thumbable in production. Stub minimally so
      # the unit under test is isolated to the Transformable methods.
      def pretty_group(raw_group) = "Pretty(#{raw_group})"
      def add_thumbnail(_permitted); end
    end
  end

  let(:host) { host_class.new }

  describe '#pretty_resource_permissions' do
    it 'returns [] for blank input' do
      expect(host.pretty_resource_permissions(nil)).to eq([])
    end

    it 'strips public/staff sentinels and maps the rest with permission labels' do
      perms = AtlasRb::Mash.new(
        'read' => ['public', 'librarians'],
        'edit' => [Permissions::STAFF_EDIT_GROUP, 'curators']
      )

      result = host.pretty_resource_permissions(perms)

      expect(result).to contain_exactly(
        ['librarians', 'Pretty(librarians)', 'View'],
        ['curators',   'Pretty(curators)',   'Manage']
      )
    end
  end

  describe '#pretty_user_permissions' do
    it 'returns [] for blank input' do
      expect(host.pretty_user_permissions(nil)).to eq([])
    end

    it 'maps each group to [raw, pretty]' do
      expect(host.pretty_user_permissions(['a', 'b']))
        .to eq([['a', 'Pretty(a)'], ['b', 'Pretty(b)']])
    end
  end

  describe '#form_group_permissions' do
    it 'accumulates group_ids keyed by ability symbol, skipping incomplete entries' do
      raw = {
        '0' => { 'group_id' => 'librarians', 'ability' => 'read' },
        '1' => { 'group_id' => 'curators',   'ability' => 'read' },
        '2' => { 'group_id' => 'editors',    'ability' => 'edit' },
        '3' => { 'group_id' => '',           'ability' => 'read' },
        '4' => { 'group_id' => 'orphan',     'ability' => '' }
      }

      expect(host.form_group_permissions(raw)).to eq(
        read: ['librarians', 'curators'],
        edit: ['editors']
      )
    end
  end

  describe '#form_preparation' do
    before do
      host.current_user = double('User', groups: ['librarians'])
    end

    it 'parses a valid embargo date and assigns flags / permissions' do
      raw = AtlasRb::Mash.new('read' => ['public'], 'edit' => [], 'embargo' => '2030-01-15')

      host.form_preparation(raw)

      expect(host.instance_variable_get(:@public)).to eq(true)
      expect(host.instance_variable_get(:@embargo)).to eq('2030-01-15')
      expect(host.instance_variable_get(:@groups)).to eq([['librarians', 'Pretty(librarians)']])
    end

    it 'rescues invalid embargo strings into an empty string' do
      raw = AtlasRb::Mash.new('read' => [], 'edit' => [], 'embargo' => 'not-a-date')

      host.form_preparation(raw)

      expect(host.instance_variable_get(:@embargo)).to eq('')
    end

    it 'rescues a nil raw_permissions into an empty embargo string' do
      host.form_preparation(nil)

      expect(host.instance_variable_get(:@embargo)).to eq('')
      expect(host.instance_variable_get(:@public)).to be_falsey
    end
  end

  describe '#transform_permissions' do
    it 'is a no-op when no permissions param is present' do
      host.params = { collection: {} }
      permitted = {}

      host.transform_permissions(permitted, :collection)

      expect(permitted).to eq({})
    end

    it 'populates :permissions from grouped form input and preserves embargo' do
      host.params = ActionController::Parameters.new(
        collection: {
          permissions: {
            '0' => { group_id: 'librarians', ability: 'read' },
            embargo: '2030-01-15'
          }
        }
      )
      permitted = {}

      host.transform_permissions(permitted, :collection)

      expect(permitted[:permissions][:read]).to eq(['librarians'])
      expect(permitted[:permissions][:embargo]).to eq('2030-01-15')
    end
  end

  describe '#mass_permissions' do
    it 'is a no-op without a :mass param' do
      host.params = {}
      permitted = { permissions: { read: ['librarians'] } }

      host.mass_permissions(permitted)

      expect(permitted[:permissions][:read]).to eq(['librarians'])
    end

    it 'sets read to [public] when :mass is "public"' do
      host.params = { mass: 'public' }
      permitted = { permissions: { read: ['librarians'] } }

      host.mass_permissions(permitted)

      expect(permitted[:permissions][:read]).to eq(['public'])
    end

    it 'strips public from read when :mass is non-public' do
      host.params = { mass: 'private' }
      permitted = { permissions: { read: ['public', 'librarians'] } }

      host.mass_permissions(permitted)

      expect(permitted[:permissions][:read]).to eq(['librarians'])
    end
  end
end
