# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MessageReceipt, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:message) { Message.create!(subject: 'Hi', recipient_nuid: '000000005') }

  it 'allows only one receipt per (message, nuid)' do
    described_class.create!(message: message, nuid: '000000005')
    expect(described_class.new(message: message, nuid: '000000005')).not_to be_valid
  end

  describe '.mark_read!' do
    it 'creates the receipt lazily and stamps read_at' do
      expect { described_class.mark_read!(message, '000000005') }
        .to change(described_class, :count).by(1)
      expect(described_class.last.read_at).to be_present
    end

    it 'keeps the original read_at on re-read (first touch wins)' do
      receipt = described_class.mark_read!(message, '000000005')
      original = receipt.read_at

      travel 1.hour do
        expect(described_class.mark_read!(message, '000000005').read_at).to eq(original)
      end
    end
  end

  describe '.dismiss!' do
    it 'stamps deleted_at without touching read_at' do
      receipt = described_class.dismiss!(message, '000000005')
      expect(receipt.deleted_at).to be_present
      expect(receipt.read_at).to be_nil
    end

    it 'reuses the read receipt rather than creating a second row' do
      described_class.mark_read!(message, '000000005')
      expect { described_class.dismiss!(message, '000000005') }
        .not_to change(described_class, :count)
    end
  end

  describe '.mark_many_read!' do
    let(:other) { Message.create!(subject: 'Group', recipient_group: 'some:group') }

    it 'creates the missing receipts, stamps them read, and counts them' do
      expect(described_class.mark_many_read!([message.id, other.id], '000000005')).to eq(2)
      expect(described_class.where(nuid: '000000005').pluck(:read_at)).to all(be_present)
    end

    it 'leaves an existing read_at alone and counts only the unread' do
      original = described_class.mark_read!(message, '000000005').read_at
      travel 1.hour do
        expect(described_class.mark_many_read!([message.id, other.id], '000000005')).to eq(1)
      end
      expect(described_class.find_by(message: message, nuid: '000000005').read_at).to eq(original)
    end

    it 'reads an unread receipt that already exists, such as a dismissed one' do
      described_class.dismiss!(message, '000000005')
      expect { described_class.mark_many_read!([message.id], '000000005') }
        .not_to change(described_class, :count)
      expect(described_class.find_by(message: message, nuid: '000000005').read_at).to be_present
    end

    it 'does nothing for an empty list' do
      expect(described_class.mark_many_read!([], '000000005')).to eq(0)
    end
  end
end
