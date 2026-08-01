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
      def flash = @flash ||= {}
    end
  end

  let(:host) { host_class.new }

  # The concern reads member_of? / admin? / admin_delegate? off current_user, so
  # each example states only the group list and the tier it cares about.
  def user_double(groups: [], admin: false, delegate: false)
    instance_double(User, groups: groups, admin?: admin, admin_delegate?: delegate).tap do |user|
      allow(user).to receive(:member_of?) { |group| groups.include?(group) }
    end
  end

  def row(group_id, ability, revocable)
    Permissions::GrantRow.new(group_id: group_id, label: "Pretty(#{group_id})",
                              ability: ability, revocable: revocable)
  end

  describe '#pretty_resource_permissions' do
    it 'returns [] for blank input' do
      expect(host.pretty_resource_permissions(nil)).to eq([])
    end

    it 'strips public/staff sentinels and maps the rest to GrantRows' do
      host.current_user = user_double(groups: %w[librarians curators])
      perms = AtlasRb::Mash.new(
        'read' => %w[public librarians],
        'edit' => [Permissions::STAFF_EDIT_GROUP, 'curators']
      )

      result = host.pretty_resource_permissions(perms)

      expect(result).to contain_exactly(row('librarians', 'read', true), row('curators', 'edit', true))
      expect(result.map(&:ability_label)).to contain_exactly('View', 'Manage')
    end

    # Rule mirrored from Atlas: a grant may only be withdrawn by a member of the
    # group it names, so a grant for someone else's group renders locked.
    it 'marks a grant for a group the user is not in as non-revocable' do
      host.current_user = user_double(groups: ['librarians'])
      perms = AtlasRb::Mash.new('read' => %w[librarians curators], 'edit' => [])

      expect(host.pretty_resource_permissions(perms))
        .to contain_exactly(row('librarians', 'read', true), row('curators', 'read', false))
    end

    it 'treats membership as per-group, not per-axis' do
      host.current_user = user_double(groups: ['curators'])
      perms = AtlasRb::Mash.new('read' => ['curators'], 'edit' => ['curators'])

      expect(host.pretty_resource_permissions(perms).map(&:revocable?)).to eq([true, true])
    end

    it 'makes every grant revocable for an :admin' do
      host.current_user = user_double(groups: [], admin: true)
      perms = AtlasRb::Mash.new('read' => ['curators'], 'edit' => ['editors'])

      expect(host.pretty_resource_permissions(perms).map(&:revocable?)).to eq([true, true])
    end

    it 'makes every grant revocable for a devolved-admin delegate' do
      host.current_user = user_double(groups: [], delegate: true)
      perms = AtlasRb::Mash.new('read' => ['curators'], 'edit' => ['editors'])

      expect(host.pretty_resource_permissions(perms).map(&:revocable?)).to eq([true, true])
    end

    # A caller with no user has no membership to appeal to; Atlas treats an
    # actor-less write the same conservative way.
    it 'revokes nothing when there is no acting user' do
      perms = AtlasRb::Mash.new('read' => ['curators'], 'edit' => [])

      expect(host.pretty_resource_permissions(perms).map(&:revocable?)).to eq([false])
    end
  end

  describe '#pretty_user_permissions' do
    it 'returns [] for blank input' do
      expect(host.pretty_user_permissions(nil)).to eq([])
    end

    it 'maps each group to [raw, pretty]' do
      expect(host.pretty_user_permissions(%w[a b]))
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
        read: %w[librarians curators],
        edit: ['editors']
      )
    end
  end

  describe '#form_preparation' do
    before do
      host.current_user = user_double(groups: ['librarians'])
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

  describe '#groups_for_permissions_picker' do
    it "scopes to the acting user's own groups for a non-admin, non-delegate user" do
      host.current_user = user_double(groups: %w[librarians curators])

      expect(host.groups_for_permissions_picker).to eq([['librarians', 'Pretty(librarians)'],
                                                        ['curators', 'Pretty(curators)']])
    end

    it 'returns the full Group registry for an :admin (fixes the empty-picker gap for admins with no personal groups)' do
      Group.create!(raw: 'northeastern:drs:repository:zzz', cosmetic: 'Alpha')
      host.current_user = user_double(groups: [], admin: true)

      expect(host.groups_for_permissions_picker).to eq([['northeastern:drs:repository:zzz', 'Alpha']])
    end

    it 'returns the full Group registry for a devolved-admin delegate' do
      Group.create!(raw: 'northeastern:drs:repository:zzz', cosmetic: 'Alpha')
      host.current_user = user_double(groups: [Permissions::ADMIN_GROUP], delegate: true)

      expect(host.groups_for_permissions_picker).to eq([['northeastern:drs:repository:zzz', 'Alpha']])
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
      permitted = { permissions: { read: %w[public librarians] } }

      host.mass_permissions(permitted)

      expect(permitted[:permissions][:read]).to eq(['librarians'])
    end

    it 'sets read to [] for private with no group grants (the silent-stays-public fix)' do
      host.params = { mass: 'private' }
      permitted = { permissions: {} }

      host.mass_permissions(permitted)

      # Definitive empty read tells Atlas to make it private — rather than
      # omitting :read and leaving the item public.
      expect(permitted[:permissions][:read]).to eq([])
    end

    it 'sets read to [] for private even when permissions is absent entirely' do
      host.params = { mass: 'private' }
      permitted = {}

      host.mass_permissions(permitted)

      expect(permitted[:permissions][:read]).to eq([])
    end
  end

  # Taking audience away from a Collection is handed to the cascade rather than
  # written here, because the container has to be written last. Works and
  # Communities never take this branch.
  describe '#apply_permissions when the submit narrows a Collection' do
    before do
      host.params = ActionController::Parameters.new(
        id: 'c-1', collection: { permissions: { '1' => { 'group_id' => 'curators', 'ability' => 'read' } } }
      )
      host.instance_variable_set(:@permissions, AtlasRb::Mash.new('read' => ['public']))
      host.current_user = user_double(groups: ['curators'])
      allow(AtlasRb::Collection).to receive(:metadata)
    end

    it 'skips its own write and reports what the cascade will do' do
      allow(NarrowingRequest).to receive(:call).and_return(
        NarrowingRequest::Outcome.new(status: :dispatched, message: 'Restricting this collection.')
      )

      host.apply_permissions('Collection', 'c-1', :collection)

      expect(AtlasRb::Collection).not_to have_received(:metadata)
      expect(host.flash[:notice]).to eq('Restricting this collection.')
    end

    # A refusal must not fall through: narrowing the container while its
    # descendants stay put is the leak this whole feature exists to close.
    it 'skips its own write on a refusal too, and alerts' do
      allow(NarrowingRequest).to receive(:call).and_return(
        NarrowingRequest::Outcome.new(status: :refused, message: 'Ask DRS staff.')
      )

      host.apply_permissions('Collection', 'c-1', :collection)

      expect(AtlasRb::Collection).not_to have_received(:metadata)
      expect(host.flash[:alert]).to eq('Ask DRS staff.')
    end

    it 'writes normally when the change is not a narrowing' do
      allow(NarrowingRequest).to receive(:call).and_return(NarrowingRequest::Outcome.new(status: :not_narrowing))

      host.apply_permissions('Collection', 'c-1', :collection)

      expect(AtlasRb::Collection).to have_received(:metadata)
    end

    it 'never consults the cascade for a Work' do
      allow(NarrowingRequest).to receive(:call)
      allow(AtlasRb::Work).to receive(:metadata)
      host.params = ActionController::Parameters.new(
        id: 'w-1', work: { permissions: { '1' => { 'group_id' => 'curators', 'ability' => 'read' } } }
      )

      host.apply_permissions('Work', 'w-1', :work)

      expect(NarrowingRequest).not_to have_received(:call)
      expect(AtlasRb::Work).to have_received(:metadata)
    end
  end

  # A refused ACL write is a 422, not an authorization failure, and it runs
  # before the descriptive save — so it reports rather than raising, or the
  # title/abstract edits in the same submit would be discarded with it.
  describe '#apply_permissions when Atlas refuses the ACL' do
    before do
      host.params = ActionController::Parameters.new(
        work: { permissions: { '1' => { 'group_id' => 'curators', 'ability' => 'read' } } }
      )
    end

    it 'flashes the invariant in the depositor’s language rather than raising' do
      allow(AtlasRb::Work).to receive(:metadata)
        .and_raise(AtlasRb::PermissionsError.new('nope', code: 'visibility_exceeds_parent'))

      expect { host.apply_permissions('Work', 'w-1', :work) }.not_to raise_error
      expect(host.flash[:alert]).to eq(Transformable::PERMISSIONS_REFUSED['visibility_exceeds_parent'])
    end

    it 'falls back to Atlas’s own message for a code Cerberus doesn’t map yet' do
      allow(AtlasRb::Work).to receive(:metadata)
        .and_raise(AtlasRb::PermissionsError.new('some new invariant', code: 'not_yet_mapped'))

      host.apply_permissions('Work', 'w-1', :work)

      expect(host.flash[:alert]).to eq('some new invariant')
    end
  end

  describe '#save_descriptive! (optimistic-lock retry)' do
    before do
      allow(host).to receive(:sleep) # don't actually back off in specs
      allow(host).to receive(:write_tmp_xml).and_return('/tmp/merged.xml')
      allow(AtlasRb::Work).to receive(:mods).and_return('<mods/>')
      allow(Metadata::MODSMerge).to receive(:call).and_return('<mods>merged</mods>')
      allow(Metadata::MODSMerge).to receive(:unchanged?).and_return(false)
    end

    def save
      host.save_descriptive!('Work', 'w-1', title: 'T', description: 'D', keywords: ['k'])
    end

    it 'retries on StaleResourceError and succeeds once the conflict clears' do
      attempts = 0
      allow(AtlasRb::Work).to receive(:update) do
        attempts += 1
        raise AtlasRb::StaleResourceError, 'stale' if attempts < 3

        true
      end

      save

      expect(attempts).to eq(3)
    end

    it 're-raises once the bounded retry budget is exhausted' do
      allow(AtlasRb::Work).to receive(:update).and_raise(AtlasRb::StaleResourceError, 'stale')

      expect { save }.to raise_error(AtlasRb::StaleResourceError)
      expect(AtlasRb::Work).to have_received(:update).exactly(5).times
    end

    it 'skips the update entirely on a no-op merge (no write, no retry)' do
      allow(Metadata::MODSMerge).to receive(:unchanged?).and_return(true)
      allow(AtlasRb::Work).to receive(:update)

      save

      expect(AtlasRb::Work).not_to have_received(:update)
    end
  end
end
