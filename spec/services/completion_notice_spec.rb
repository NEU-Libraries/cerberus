# frozen_string_literal: true

require 'rails_helper'

# `change`'s negated form reads badly inside a compound matcher, so name it.
RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe CompletionNotice do
  describe '.deliver' do
    it 'records the notice and sends the inbox message when there is an actor' do
      notice = described_class.deliver(kind: 'set_reindex', subject: 'Set reindex finished',
                                       body: '4 resources reindexed.', to_nuid: '000000004',
                                       subject_noid: 'abc123', payload: { count: 4 })

      expect(notice.kind).to eq('set_reindex')
      expect(notice.actor_nuid).to eq('000000004')
      expect(notice.subject_noid).to eq('abc123')
      expect(notice.detail(:count)).to eq(4)

      message = Message.last
      expect(message.recipient_nuid).to eq('000000004')
      expect(message.subject).to eq('Set reindex finished')
      expect(message).to be_system
    end

    it 'still records the notice when there is no actor to tell' do
      expect { described_class.deliver(kind: 'visibility_cascade', subject: 'Cascade finished') }
        .to change(AdminNotice, :count).by(1)
        .and(not_change(Message, :count))
    end

    it 'sends no message to the guest identity, and records the notice anyway' do
      guest = Rails.application.config.x.cerberus.guest_nuid

      expect { described_class.deliver(kind: 'load_report', subject: 'Load finished', to_nuid: guest) }
        .to change(AdminNotice, :count).by(1)
        .and(not_change(Message, :count))
    end

    it 'returns the notice' do
      expect(described_class.deliver(kind: 'load_report', subject: 'Load finished')).to be_a(AdminNotice)
    end
  end
end
