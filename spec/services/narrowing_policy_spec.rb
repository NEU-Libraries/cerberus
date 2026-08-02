# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NarrowingPolicy do
  def impact(count: 3, over_cap: false, owned_by: nil)
    instance_double(NarrowingImpact, count: count, over_cap?: over_cap).tap do |double|
      allow(double).to receive(:wholly_owned_by?) { |nuid| nuid.present? && nuid == owned_by }
    end
  end

  def user(role:, nuid: '000000010')
    User.new(email: "#{nuid}@example.com", nuid: nuid, role: role, groups: [])
  end

  describe 'the admin tail' do
    it 'lets an admin narrow a container they do not own' do
      decision = described_class.call(impact: impact(owned_by: '000000011'),
                                      actor:  user(role: 'admin', nuid: '000000004'))

      expect(decision).to be_allowed
      expect(decision.affected).to eq(3)
    end
  end

  describe 'the depositor tail' do
    it 'lets a depositor narrow a container holding only their own material' do
      decision = described_class.call(impact: impact(owned_by: '000000010'),
                                      actor:  user(role: 'standard'))

      expect(decision).to be_allowed
    end

    it 'refuses a depositor once anyone else has material in the subtree' do
      decision = described_class.call(impact: impact(owned_by: '000000011'),
                                      actor:  user(role: 'standard'))

      expect(decision).to be_escalate
      expect(decision.reason).to eq(described_class::NOT_SOLE_DEPOSITOR)
    end
  end

  # The middle of the curve: rights enough to trigger a large cascade, without
  # the authority to own the fallout. Refusing these is the point of the rule,
  # not a gap in it.
  describe 'the middle' do
    it 'refuses the devolved-admin tier' do
      delegate = User.new(email: 'jane@example.com', nuid: '000000002', role: 'privileged',
                          groups: [Permissions::ADMIN_GROUP])
      expect(delegate).to be_admin_delegate

      decision = described_class.call(impact: impact(owned_by: '000000011'), actor: delegate)

      expect(decision).to be_escalate
    end

    it 'refuses a staff-group editor' do
      staff = User.new(email: 'susan@example.com', nuid: '000000006', role: 'privileged',
                       groups: [Permissions::STAFF_EDIT_GROUP])

      expect(described_class.call(impact: impact(owned_by: '000000011'), actor: staff)).to be_escalate
    end

    it 'refuses an unauthenticated caller' do
      expect(described_class.call(impact: impact(owned_by: '000000010'), actor: nil)).to be_escalate
    end
  end

  # Size is not a question of authority: a cascade too large to finish leaks the
  # same way an un-narrowed subtree does, so it outranks the admin branch.
  describe 'the size guard' do
    it 'refuses an oversized subtree even for an admin' do
      decision = described_class.call(impact: impact(count: 50_000, over_cap: true),
                                      actor:  user(role: 'admin', nuid: '000000004'))

      expect(decision).to be_escalate
      expect(decision.reason).to eq(described_class::TOO_LARGE)
      expect(decision.affected).to eq(50_000)
    end

    it 'refuses an oversized subtree the depositor wholly owns' do
      decision = described_class.call(impact: impact(count: 50_000, over_cap: true, owned_by: '000000010'),
                                      actor:  user(role: 'standard'))

      expect(decision).to be_escalate
      expect(decision.reason).to eq(described_class::TOO_LARGE)
    end
  end
end
