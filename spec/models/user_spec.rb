# frozen_string_literal: true

require 'rails_helper'

describe User do
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
end
