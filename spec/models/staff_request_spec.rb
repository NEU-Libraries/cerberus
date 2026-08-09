# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StaffRequest, type: :model do
  let(:attributes) do
    { kind: 'withdraw', subject_noid: 'abc123', subject_type: 'Work',
      subject_title: 'thesis.pdf', requester_nuid: '000000002' }
  end

  describe 'validations' do
    it 'is valid with the required attributes and defaults to open' do
      request = described_class.create!(attributes)
      expect(request).to be_open
      expect(request.status).to eq('open')
    end

    it 'rejects an unknown kind, subject_type, status or resolution' do
      expect(described_class.new(attributes.merge(kind: 'delete'))).not_to be_valid
      expect(described_class.new(attributes.merge(subject_type: 'FileSet'))).not_to be_valid
      expect(described_class.new(attributes.merge(status: 'pending'))).not_to be_valid
      expect(described_class.new(attributes.merge(resolution: 'maybe'))).not_to be_valid
    end

    it 'allows a nil resolution while the request is unresolved' do
      expect(described_class.new(attributes.merge(resolution: nil))).to be_valid
    end

    it 'requires a subject noid and a requester' do
      expect(described_class.new(attributes.except(:subject_noid))).not_to be_valid
      expect(described_class.new(attributes.except(:requester_nuid))).not_to be_valid
    end

    it 'normalizes a blank note to nil so an empty textarea is not stored as text' do
      expect(described_class.create!(attributes.merge(note: '  ')).note).to be_nil
    end
  end

  describe '#admin_only?' do
    it 'is true for restrict, because only :admin can run a visibility cascade' do
      expect(described_class.new(kind: 'restrict')).to be_admin_only
      expect(described_class.new(kind: 'withdraw')).not_to be_admin_only
      expect(described_class.new(kind: 'move')).not_to be_admin_only
    end
  end

  describe 'lifecycle' do
    let(:request) { described_class.create!(attributes) }

    it 'claims and records who claimed it' do
      request.claim!('000000004')
      expect(request).to be_claimed
      expect(request.claimed_by_nuid).to eq('000000004')
      expect(request.claimed_at).to be_present
    end

    it 'unclaims back to open and clears the claim' do
      request.claim!('000000004')
      request.unclaim!
      expect(request).to be_open
      expect(request.claimed_by_nuid).to be_nil
      expect(request.claimed_at).to be_nil
    end

    it 'resolves with an actor, a resolution and a note' do
      request.resolve!(nuid: '000000004', resolution: 'declined', note: 'Already withdrawn.')
      expect(request).to be_resolved
      expect(request.resolved_by_nuid).to eq('000000004')
      expect(request.resolution).to eq('declined')
      expect(request.resolution_note).to eq('Already withdrawn.')
      expect(request.resolved_at).to be_present
    end

    it 'refuses to claim or unclaim a resolved request' do
      request.resolve!(nuid: '000000004')
      expect(request.claim!('000000005')).to be(false)
      expect(request.unclaim!).to be(false)
      expect(request.reload).to be_resolved
    end
  end

  describe 'scopes' do
    let!(:old_request) { described_class.create!(attributes.merge(created_at: 3.days.ago)) }
    let!(:new_request) { described_class.create!(attributes.merge(created_at: 1.hour.ago)) }

    it 'orders oldest first, so the longest wait is worked first' do
      expect(described_class.oldest_first.to_a).to eq([old_request, new_request])
    end

    it 'excludes resolved requests from .unresolved' do
      new_request.resolve!(nuid: '000000004')
      expect(described_class.unresolved.to_a).to eq([old_request])
    end

    it 'filters by a known status and falls through to everything on an unknown one' do
      new_request.claim!('000000004')
      expect(described_class.with_status('claimed').to_a).to eq([new_request])
      expect(described_class.with_status('nonsense').count).to eq(2)
    end

    it 'buckets by the day a request opened or resolved' do
      new_request.resolve!(nuid: '000000004')
      expect(described_class.opened_on(3.days.ago.to_date).to_a).to eq([old_request])
      expect(described_class.resolved_on(Time.zone.today).to_a).to eq([new_request])
    end
  end
end
