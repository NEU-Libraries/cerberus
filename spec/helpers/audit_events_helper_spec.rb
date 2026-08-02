# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditEventsHelper, type: :helper do
  def event(action:, change_type:, payload: nil, at: '2026-05-26T12:34:56Z')
    { 'action'            => action,
      'change_type'       => change_type,
      'payload'           => payload,
      'occurred_at'       => at,
      'actor_nuid'        => '000000004',
      'on_behalf_of_nuid' => nil }
  end

  describe '#audit_event_view_cell' do
    it 'links a permissions update to the rights-history page' do
      html = helper.audit_event_view_cell(event(action: 'update', change_type: 'permissions'), 'w-1')
      expect(html).to include('View')
      expect(html).to include('/resources/w-1/rights_history')
      expect(html).to include('evt-20260526123456') # deep-link #anchor
    end

    it 'links a permissions create (the initial grant) to the rights-history page' do
      html = helper.audit_event_view_cell(event(action: 'create', change_type: 'permissions'), 'w-1')
      expect(html).to include('View')
      expect(html).to include('/resources/w-1/rights_history')
    end

    it 'links a full MODS-document update to the mods-history page' do
      html = helper.audit_event_view_cell(
        event(action: 'update', change_type: 'metadata', payload: { 'source' => 'mods' }), 'w-1'
      )
      expect(html).to include('/resources/w-1/mods_history')
    end

    it 'also links a title/description field-patch (plain_title= edits the MODS doc too)' do
      html = helper.audit_event_view_cell(
        event(action: 'update', change_type: 'metadata', payload: { 'fields' => %w[title] }), 'w-1'
      )
      expect(html).to include('/resources/w-1/mods_history')
    end

    it 'renders nothing for non-update rows' do
      expect(helper.audit_event_view_cell(event(action: 'create', change_type: 'structural'), 'w-1')).to be_nil
    end

    it 'renders nothing for a metadata create row (no prior MODS version to diff)' do
      cell = helper.audit_event_view_cell(event(action: 'create', change_type: 'metadata', payload: { 'source' => 'mods' }), 'w-1')
      expect(cell).to be_nil
    end
  end

  describe '#acl_grant_pills' do
    it 'renders a muted em-dash for an empty slot' do
      expect(helper.acl_grant_pills([])).to include('—')
    end

    it 'tints only the marked grant with the given state' do
      html = helper.acl_grant_pills(%w[public staff], marked: %w[public], state: 'added')
      expect(html).to include('rights-diff__pill--added">public')
      expect(html).to include('rights-diff__pill">staff')
    end
  end

  # Atlas sends the embargo as an ISO8601 string inside the same permissions
  # snapshot as the grant slots; "no embargo" arrives as nil, '', or an absent
  # key depending on the resource's history and when the event was written.
  describe 'embargo diff rendering' do
    let(:embargoed)   { { 'embargo' => '2027-12-31T00:00:00+00:00' } }
    let(:unembargoed) { { 'embargo' => nil } }

    describe '#embargo_recorded?' do
      it 'is true when either side carries a date' do
        expect(helper.embargo_recorded?(unembargoed, embargoed)).to be(true)
        expect(helper.embargo_recorded?(embargoed, unembargoed)).to be(true)
      end

      it 'is false when neither side does, so the row stays off the page' do
        expect(helper.embargo_recorded?(unembargoed, unembargoed)).to be(false)
      end

      it 'is false for events written before Atlas audited the key' do
        expect(helper.embargo_recorded?({ 'read' => %w[public] }, { 'read' => [] })).to be(false)
      end
    end

    describe '#embargo_changed?' do
      it 'treats nil, empty string, and an absent key as the same fact' do
        expect(helper.embargo_changed?({ 'embargo' => nil }, { 'embargo' => '' })).to be(false)
        expect(helper.embargo_changed?({}, { 'embargo' => nil })).to be(false)
      end

      it 'detects a set and a lift' do
        expect(helper.embargo_changed?(unembargoed, embargoed)).to be(true)
        expect(helper.embargo_changed?(embargoed, unembargoed)).to be(true)
      end
    end

    describe '#embargo_diff_cell' do
      it 'renders the date as prose, not an identifier pill' do
        html = helper.embargo_diff_cell(embargoed['embargo'])
        expect(html).to include('December 31, 2027')
        expect(html).to include('rights-diff__date')
        expect(html).not_to include('rights-diff__pill')
      end

      it 'renders "None" for a blank side' do
        expect(helper.embargo_diff_cell(nil)).to include('None')
        expect(helper.embargo_diff_cell('')).to include('None')
      end

      it 'tints only when given a state' do
        expect(helper.embargo_diff_cell(embargoed['embargo'], state: 'added'))
          .to include('rights-diff__date--added')
        expect(helper.embargo_diff_cell(embargoed['embargo'])).not_to include('rights-diff__date--')
      end

      it 'degrades an unparseable remote value to "None" rather than raising' do
        expect { helper.embargo_diff_cell('not-a-date') }.not_to raise_error
        expect(helper.embargo_diff_cell('not-a-date')).to include('None')
      end
    end

    describe 'the audit-log one-liner' do
      def summary(before, after)
        helper.audit_event_payload_summary(
          event(action: 'update', change_type: 'permissions',
                payload: { 'before' => before, 'after' => after })
        )
      end

      it 'reports a set embargo in compact ISO form' do
        expect(summary(unembargoed, embargoed)).to include('embargo none → 2027-12-31')
      end

      it 'reports a lifted embargo' do
        expect(summary(embargoed, unembargoed)).to include('embargo 2027-12-31 → none')
      end

      it 'appends the embargo clause after the grant clauses' do
        text = summary({ 'read' => [], 'embargo' => nil },
                       { 'read' => %w[public], 'embargo' => '2027-12-31T00:00:00+00:00' })
        expect(text).to include('read +public · embargo none → 2027-12-31')
      end

      it 'says nothing when the embargo did not move' do
        expect(summary(embargoed.merge('read' => []), embargoed.merge('read' => %w[public])))
          .not_to include('embargo')
      end
    end
  end

  # Atlas emits the per-rendition download gate as a `permissions` update too,
  # separated from an ACL edit only by payload `source`. Its before/after are a
  # sparse tier => read-groups map, not the ACL envelope.
  describe 'derivative (per-rendition) permission events' do
    def tier_event(before, after)
      event(action: 'update', change_type: 'permissions',
            payload: { 'before' => before, 'after' => after,
                       'source' => 'derivative_permissions' })
    end

    describe '#derivative_permissions_payload?' do
      it 'distinguishes a rendition-gate payload from an ACL one' do
        expect(helper.derivative_permissions_payload?({ 'source' => 'derivative_permissions' })).to be(true)
        expect(helper.derivative_permissions_payload?({ 'source' => 'mods' })).to be(false)
        expect(helper.derivative_permissions_payload?({ 'before' => {}, 'after' => {} })).to be(false)
      end
    end

    describe '#derivative_tier_rows' do
      it 'lists only the tiers a side mentions, in narrowing order' do
        rows = helper.derivative_tier_rows({ 'large' => [] }, { 'small' => [], 'master' => [] })
        expect(rows).to eq(%w[small large master])
      end

      it 'sorts a tier it has not been taught about last rather than dropping it' do
        rows = helper.derivative_tier_rows({}, { 'hologram' => [], 'small' => [] })
        expect(rows).to eq(%w[small hologram])
      end
    end

    describe '#tier_label' do
      it 'gives the ladder prose names' do
        expect(helper.tier_label('service')).to eq('Service (deep zoom)')
        expect(helper.tier_label('master')).to eq('Master (original)')
      end

      it 'falls back to the raw token for an unknown tier' do
        expect(helper.tier_label('hologram')).to eq('Hologram')
      end
    end

    describe 'the audit-log one-liner' do
      it 'summarises the tier grants that moved' do
        text = helper.audit_event_payload_summary(
          tier_event({ 'large' => %w[public] }, { 'large' => %w[staff] })
        )
        expect(text).to include('large −public +staff')
      end

      # The bug this replaced: `source` was matched for presence, so any source
      # that was not MODS still rendered as "MODS document".
      it 'does not mistake a rendition-gate change for a MODS edit' do
        text = helper.audit_event_payload_summary(
          tier_event({ 'large' => %w[public] }, { 'large' => %w[staff] })
        )
        expect(text).not_to include('MODS document')
      end

      it 'still labels a genuine MODS update' do
        text = helper.audit_event_payload_summary(
          event(action: 'update', change_type: 'metadata', payload: { 'source' => 'mods' })
        )
        expect(text).to include('MODS document')
      end

      it 'reports a newly gated tier' do
        text = helper.audit_event_payload_summary(tier_event({}, { 'master' => %w[staff] }))
        expect(text).to include('master +staff')
      end
    end
  end
end
