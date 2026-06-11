# frozen_string_literal: true

require 'rails_helper'

describe 'audit_events/_history.html.haml' do
  let(:resource_id) { 'abc12345' }

  def render_with(can_read: true, events: [])
    allow(view).to receive(:can?).with(:read, :audit_event).and_return(can_read)
    allow(AtlasRb::Resource).to receive(:history)
      .with(resource_id, nuid: Current.nuid)
      .and_return(AtlasRb::Mash.new('resource_id' => resource_id, 'events' => events))
    render partial: 'audit_events/history', locals: { resource_id: resource_id }
  end

  def event(action:, change_type: nil, payload: nil, actor: '000000002', on_behalf_of: nil)
    { 'action'            => action,
      'change_type'       => change_type,
      'payload'           => payload,
      'actor_nuid'        => actor,
      'occurred_at'       => '2026-05-26T12:34:56Z',
      'on_behalf_of_nuid' => on_behalf_of }
  end

  context 'when the user cannot read audit events' do
    it 'renders nothing — no shell, no atlas_rb call' do
      allow(view).to receive(:can?).with(:read, :audit_event).and_return(false)
      expect(AtlasRb::Resource).not_to receive(:history)
      render partial: 'audit_events/history', locals: { resource_id: resource_id }
      expect(rendered).to be_blank
    end
  end

  context 'when the user can read audit events but the history is empty' do
    before { render_with(events: []) }

    it 'renders the empty-state copy without a table' do
      expect(rendered).to include('No recorded events')
      expect(rendered).to include('Actions taken against this resource will appear here.')
      expect(rendered).not_to have_css('table.audit-event-table')
    end

    it 'still renders the section shell + title' do
      expect(rendered).to have_css('.audit-history .audit-history__title', text: 'Audit log')
    end
  end

  context 'with a full set of event types' do
    let(:events) do
      [event(action: 'create'),
       event(action: 'update'),
       event(action: 'tombstone'),
       event(action: 'restore'),
       event(action: 'mystery_action')]
    end

    before { render_with(events: events) }

    it 'renders the section header with title and event count' do
      expect(rendered).to have_css('.audit-history__title', text: 'Audit log')
      expect(rendered).to have_css('.audit-history__count', text: '5 events')
      expect(rendered).to have_css('.audit-history__subtitle', text: 'Reverse chronological')
    end

    it 'renders four column headers — When / Action / Detail / Who (actor+on-behalf merged; resource Type absent)' do
      %w[When Action Detail Who].each do |label|
        expect(rendered).to have_css('table.audit-event-table thead th', text: label)
      end
      expect(rendered).not_to have_css('table.audit-event-table thead th', text: 'On behalf of')
      expect(rendered).not_to have_css('table.audit-event-table thead th', text: 'Type')
    end

    it 'renders the create/update/tombstone/restore action labels' do
      expect(rendered).to have_css('.audit-event--create .audit-event__action-label', text: 'Created')
      expect(rendered).to have_css('.audit-event--update .audit-event__action-label', text: 'Updated')
      expect(rendered).to have_css('.audit-event--tombstone .audit-event__action-label', text: 'Tombstoned')
      expect(rendered).to have_css('.audit-event--restore .audit-event__action-label', text: 'Restored')
    end

    it 'attaches per-action FA icons that drive the row rail colour via CSS' do
      expect(rendered).to have_css('.audit-event--create .audit-event__action-icon.fa-circle-plus')
      expect(rendered).to have_css('.audit-event--update .audit-event__action-icon.fa-pen')
      expect(rendered).to have_css('.audit-event--tombstone .audit-event__action-icon.fa-trash-can')
      expect(rendered).to have_css('.audit-event--restore .audit-event__action-icon.fa-rotate-left')
    end

    it 'falls back to the generic partial + humanised label for unknown action types' do
      expect(rendered).to have_css('tr.audit-event.audit-event--generic')
      expect(rendered).to have_css('.audit-event--generic .audit-event__action-label', text: 'Mystery action')
    end

    it 'shows a muted em-dash in the Detail column for events with no change_type or payload' do
      expect(rendered).to have_css('.audit-event--update .audit-event__action-label', text: 'Updated')
      expect(rendered).not_to have_css('.audit-event__change-type')
      expect(rendered).to have_css('.audit-event__detail-cell .audit-event__detail-empty', text: '—')
    end

    it 'renders the timestamp split into date and time, with the full ISO in title' do
      expect(rendered).to have_css('.audit-event__when[title="2026-05-26T12:34:56Z"]')
      expect(rendered).to have_css('.audit-event__when-date', text: '2026-05-26')
      expect(rendered).to have_css('.audit-event__when-time', text: '12:34 UTC')
    end

    it 'renders the actor NUID as a monospace chip' do
      expect(rendered).to have_css('.audit-event__nuid', text: '000000002')
    end
  end

  context 'with structural-relationship verbs (Option C — dedicated partials, not generic)' do
    before do
      render_with(events: [event(action: 'reparent', change_type: 'structural',
                                 payload: { 'to' => 'col987', 'from' => 'col111' }),
                           event(action: 'link_member', change_type: 'structural',
                                 payload: { 'collection' => 'col456' }),
                           event(action: 'unlink_member', change_type: 'structural',
                                 payload: { 'collection' => 'col456' })])
    end

    it 'renders reparent / link / unlink with their own tone rows and labels' do
      expect(rendered).to have_css('.audit-event--reparent .audit-event__action-label', text: 'Reparented')
      expect(rendered).to have_css('.audit-event--link .audit-event__action-label', text: 'Linked')
      expect(rendered).to have_css('.audit-event--unlink .audit-event__action-label', text: 'Unlinked')
    end

    it 'gives each its own Font Awesome icon and does not fall through to generic' do
      expect(rendered).to have_css('.audit-event--reparent .audit-event__action-icon.fa-folder-tree')
      expect(rendered).to have_css('.audit-event--link .audit-event__action-icon.fa-link')
      expect(rendered).to have_css('.audit-event--unlink .audit-event__action-icon.fa-link-slash')
      expect(rendered).not_to have_css('tr.audit-event--generic')
    end

    it 'summarises the move / link target in the Detail column' do
      expect(rendered).to have_css('.audit-event__detail-summary', text: 'moved to col987')
      expect(rendered).to have_css('.audit-event__detail-summary', text: 'to col456')
      expect(rendered).to have_css('.audit-event__detail-summary', text: 'from col456')
    end
  end

  context 'Detail column on update rows (Option A — metadata vs permissions, + payload summary)' do
    it 'labels a metadata update "Metadata" and lists the changed fields' do
      render_with(events: [event(action: 'update', change_type: 'metadata',
                                 payload: { 'fields' => %w[title description] })])
      expect(rendered).to have_css('.audit-event--update .audit-event__action-label', text: 'Updated')
      expect(rendered).to have_css('.audit-event--update .audit-event__change-type', text: 'Metadata')
      expect(rendered).to have_css('.audit-event__detail-summary', text: 'title, description')
    end

    it 'labels a permissions update "Permissions" (with the link-hook modifier) and diffs the ACL' do
      render_with(events: [event(action: 'update', change_type: 'permissions',
                                 payload: { 'before' => { 'read' => ['staff'] },
                                            'after'  => { 'read' => %w[staff public], 'edit' => ['editors'] } })])
      expect(rendered).to have_css('.audit-event__change-type.audit-event__change-type--permissions',
                                   text: 'Permissions')
      expect(rendered).to have_css('.audit-event__detail-summary', text: 'read +public')
      expect(rendered).to have_css('.audit-event__detail-summary', text: 'edit +editors')
    end

    it 'humanises an unknown change_type rather than dropping it' do
      render_with(events: [event(action: 'update', change_type: 'provenance')])
      expect(rendered).to have_css('.audit-event--update .audit-event__change-type', text: 'Provenance')
    end

    it 'renders the category + summary in the Detail column cell, not the action cell' do
      render_with(events: [event(action: 'update', change_type: 'metadata',
                                 payload: { 'fields' => ['title'] })])
      expect(rendered).to have_css('.audit-event--update .audit-event__detail-cell .audit-event__change-type')
      expect(rendered).to have_css('.audit-event--update .audit-event__detail-cell .audit-event__detail-summary')
    end
  end

  context 'when on_behalf_of_nuid is present (proxy / acting-as)' do
    it 'stacks a muted "for <target>" beneath the actor in the WHO cell' do
      render_with(events: [event(action: 'create', actor: '000000004', on_behalf_of: '000000007')])
      expect(rendered).to have_css('.audit-event--create .audit-event__who .audit-event__nuid', text: '000000004')
      expect(rendered).to have_css('.audit-event--create .audit-event__on-behalf', text: 'for')
      expect(rendered).to have_css('.audit-event--create .audit-event__on-behalf .audit-event__nuid',
                                   text: '000000007')
    end
  end

  context 'when on_behalf_of_nuid is nil (the common case)' do
    it 'renders just the actor pill — no on-behalf line, no em-dash column' do
      render_with(events: [event(action: 'create', actor: '000000004')])
      expect(rendered).to have_css('.audit-event--create .audit-event__nuid', text: '000000004')
      expect(rendered).not_to have_css('.audit-event__on-behalf')
      expect(rendered).not_to have_css('.audit-event__nuid--empty')
    end
  end
end
