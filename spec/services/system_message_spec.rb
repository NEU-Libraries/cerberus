# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemMessage do
  describe '.deliver' do
    it 'creates a system-sent message to a NUID' do
      message = described_class.deliver(to_nuid: '000000005', subject: 'Load finished', body: 'All done.')

      expect(message).to be_persisted
      expect(message).to be_system
      expect(message.recipient_nuid).to eq('000000005')
    end

    it 'creates a group-addressed message' do
      message = described_class.deliver(to_group: 'northeastern:drs:repository:staff', subject: 'Heads up')

      expect(message).to be_persisted
      expect(message.recipient_group).to eq('northeastern:drs:repository:staff')
    end

    it 'declines to message the guest identity' do
      guest_nuid = Rails.application.config.x.cerberus.guest_nuid

      expect(described_class.deliver(to_nuid: guest_nuid, subject: 'Hi')).to be_nil
      expect(Message.count).to eq(0)
    end
  end
end
