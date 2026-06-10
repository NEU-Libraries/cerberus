# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message, type: :model do
  let(:reader) do
    User.new(email: 'reader@example.com', password: 'password',
             nuid: '000000005', role: 'standard',
             groups: ['northeastern:drs:repository:staff'])
  end

  describe 'validations' do
    it 'requires a subject' do
      expect(described_class.new(recipient_nuid: '000000005')).not_to be_valid
    end

    it 'requires exactly one of recipient_nuid / recipient_group' do
      expect(described_class.new(subject: 'Hi')).not_to be_valid
      expect(described_class.new(subject: 'Hi', recipient_nuid: '000000005',
                                 recipient_group: 'northeastern:drs:repository:staff')).not_to be_valid
      expect(described_class.new(subject: 'Hi', recipient_nuid: '000000005')).to be_valid
      expect(described_class.new(subject: 'Hi', recipient_group: 'northeastern:drs:repository:staff')).to be_valid
    end

    it 'normalizes blank recipients to nil so an empty form field does not count as a recipient' do
      message = described_class.new(subject: 'Hi', recipient_nuid: '000000005', recipient_group: '')
      expect(message).to be_valid
      expect(message.recipient_group).to be_nil
    end

    it 'rejects the guest identity as a recipient' do
      guest_nuid = Rails.application.config.x.cerberus.guest_nuid
      expect(described_class.new(subject: 'Hi', recipient_nuid: guest_nuid)).not_to be_valid
    end
  end

  describe '#system?' do
    it 'is true when sender_nuid is nil and false for a human sender' do
      expect(described_class.new(sender_nuid: nil)).to be_system
      expect(described_class.new(sender_nuid: '000000002')).not_to be_system
    end
  end

  describe '.inbox_for' do
    let!(:direct) do
      described_class.create!(subject: 'Direct', recipient_nuid: reader.nuid, sender_nuid: '000000002')
    end
    let!(:group_message) do
      described_class.create!(subject: 'Group', recipient_group: 'northeastern:drs:repository:staff')
    end
    let!(:someone_elses) { described_class.create!(subject: 'Other', recipient_nuid: '000000099') }
    let!(:other_group) { described_class.create!(subject: 'OtherG', recipient_group: 'some:other:group') }

    it 'returns messages addressed to the NUID or to a session group, and nothing else' do
      expect(described_class.inbox_for(reader)).to contain_exactly(direct, group_message)
    end

    it 'orders newest first' do
      direct.update!(created_at: 2.days.ago)
      expect(described_class.inbox_for(reader).to_a).to eq([group_message, direct])
    end

    it 'excludes dismissed messages' do
      MessageReceipt.dismiss!(direct, reader.nuid)
      expect(described_class.inbox_for(reader)).to contain_exactly(group_message)
    end

    it 'does not let one user\'s dismissal hide a group message from others' do
      MessageReceipt.dismiss!(group_message, '000000099')
      expect(described_class.inbox_for(reader)).to include(group_message)
    end

    it 'is read-time for groups: a user sees group messages sent before they joined' do
      late_joiner = User.new(email: 'late@example.com', password: 'password',
                             nuid: '000000098', role: 'standard',
                             groups: ['northeastern:drs:repository:staff'])
      expect(described_class.inbox_for(late_joiner)).to include(group_message)
    end

    it 'tolerates a user with no groups' do
      loner = User.new(email: 'loner@example.com', password: 'password',
                       nuid: '000000097', role: 'standard', groups: nil)
      expect(described_class.inbox_for(loner)).to be_empty
    end
  end

  describe '.unread_count_for' do
    let!(:direct) { described_class.create!(subject: 'Direct', recipient_nuid: reader.nuid) }
    let!(:group_message) do
      described_class.create!(subject: 'Group', recipient_group: 'northeastern:drs:repository:staff')
    end

    it 'counts inbox messages without a read receipt' do
      expect(described_class.unread_count_for(reader)).to eq(2)

      MessageReceipt.mark_read!(direct, reader.nuid)
      expect(described_class.unread_count_for(reader)).to eq(1)
    end

    it 'does not count dismissed messages' do
      MessageReceipt.dismiss!(group_message, reader.nuid)
      expect(described_class.unread_count_for(reader)).to eq(1)
    end
  end
end
