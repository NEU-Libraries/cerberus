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
end
