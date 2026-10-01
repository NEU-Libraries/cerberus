# frozen_string_literal: true

require 'rails_helper'

describe User do
  # Namae only understands person-shaped names. A blank result used to hide the
  # whole navbar user block — Log Out included — so an account named after a
  # role could not sign out at all.
  describe '#pretty_name' do
    it 'reorders a person-shaped name' do
      expect(described_class.new(name: 'Doe, Jane').pretty_name).to eq('Jane Doe')
    end

    it 'falls back to the raw name when it is not person-shaped' do
      user = described_class.new(name: 'Law Library Staffer (DRS Fixture)')

      expect(user.pretty_name).to eq('Law Library Staffer (DRS Fixture)')
      expect(user.to_s).to be_present
    end

    it 'is blank only when there is no name at all' do
      expect(described_class.new(name: nil).pretty_name).to eq('')
    end

    # A curator set the name to render exactly so, so it is not Namae'd.
    it 'shows a curated display name verbatim over the SSO name' do
      user = described_class.new(name: 'Reader, Licensed Resources', display_name: 'Mickey Gasper')

      expect(user.pretty_name).to eq('Mickey Gasper')
      expect(user.to_s).to eq('Mickey Gasper')
    end
  end

  describe '.from_atlas' do
    let(:values) do
      OpenStruct.new(email: 'reader@example.com', nuid: '000000014', name: 'Reader, Licensed Resources',
                     groups: ['g'], role: 'standard', affiliation: 'staff')
    end

    it 'carries the curated Person name from the directory entry' do
      allow(AtlasRb::User).to receive(:find_by_nuid).with('000000014', nuid: '000000014')
                                                    .and_return({ 'display_name' => 'Mickey Gasper' })

      user = described_class.from_atlas(values)

      expect(user.display_name).to eq('Mickey Gasper')
      expect([user.email, user.nuid, user.role, user.affiliation])
        .to eq(['reader@example.com', '000000014', 'standard', 'staff'])
    end

    it 'leaves display_name nil when the NUID has no Person' do
      allow(AtlasRb::User).to receive(:find_by_nuid).and_return({ 'display_name' => nil })

      expect(described_class.from_atlas(values).pretty_name).to eq('Licensed Resources Reader')
    end

    # A failed read must not block sign-in.
    it 'falls back to the SSO name when the directory read fails' do
      allow(AtlasRb::User).to receive(:find_by_nuid).and_raise(Faraday::ConnectionFailed, 'down')

      expect(described_class.from_atlas(values).display_name).to be_nil
    end
  end

  describe 'session serialization' do
    it 'round-trips display_name' do
      user = described_class.new(email: 'e', nuid: 'n', name: 'Doe, Jane', groups: [], role: 'standard',
                                 display_name: 'Jane D.')

      restored = described_class.serialize_from_session(*described_class.serialize_into_session(user))

      expect(restored.display_name).to eq('Jane D.')
    end

    # A session written before the field existed has six elements.
    it 'still restores a six-element session' do
      restored = described_class.serialize_from_session('e', 'n', 'Doe, Jane', [], 'standard', nil)

      expect(restored.display_name).to be_nil
      expect(restored.pretty_name).to eq('Jane Doe')
    end
  end

  describe '#can_bypass_embargo?' do
    it 'is true for an Atlas admin' do
      user = described_class.new(nuid: '000000004', groups: [], role: 'admin')
      expect(user.can_bypass_embargo?).to be(true)
    end

    it 'is true for a member of the staff grouper group' do
      user = described_class.new(nuid: '000000002', groups: [Permissions::STAFF_EDIT_GROUP], role: 'standard')
      expect(user.can_bypass_embargo?).to be(true)
    end

    it 'is false for a signed-in user with neither admin role nor staff group' do
      user = described_class.new(nuid: '000000005', groups: ['editors'], role: 'standard')
      expect(user.can_bypass_embargo?).to be(false)
    end

    it 'is false for a user with no groups' do
      user = described_class.new(nuid: '000000005', groups: [], role: 'standard')
      expect(user.can_bypass_embargo?).to be(false)
    end
  end

  describe '#admin_delegate?' do
    it 'is true for :privileged role + the admin group' do
      user = described_class.new(nuid: '000000002', role: 'privileged',
                                 groups: [Permissions::STAFF_EDIT_GROUP, Permissions::ADMIN_GROUP])
      expect(user.admin_delegate?).to be(true)
    end

    it 'is false for :privileged role without the admin group (neither alone is sufficient)' do
      user = described_class.new(nuid: '000000002', role: 'privileged', groups: [Permissions::STAFF_EDIT_GROUP])
      expect(user.admin_delegate?).to be(false)
    end

    it 'is false for the admin group without :privileged role' do
      user = described_class.new(nuid: '000000005', role: 'standard', groups: [Permissions::ADMIN_GROUP])
      expect(user.admin_delegate?).to be(false)
    end

    it 'is false for full :admin (admin? covers it separately; admin_delegate? is the narrower case)' do
      user = described_class.new(nuid: '000000004', role: 'admin', groups: [])
      expect(user.admin_delegate?).to be(false)
    end
  end
end
