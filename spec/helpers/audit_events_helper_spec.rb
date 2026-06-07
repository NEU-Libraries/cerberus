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
end
