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
