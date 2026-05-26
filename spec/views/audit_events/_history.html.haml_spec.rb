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

  def event(action:, actor: '000000002', resource_type: 'Work', on_behalf_of: nil, occurred_at: '2026-05-26T12:34:56Z')
    { 'action'            => action,
      'actor_nuid'        => actor,
      'resource_type'     => resource_type,
      'occurred_at'       => occurred_at,
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

    it 'renders a table with all four column headers (Type intentionally absent — the page is already scoped to the resource)' do
      %w[When Action Actor].each do |label|
        expect(rendered).to have_css('table.audit-event-table thead th', text: label)
      end
      expect(rendered).to have_css('table.audit-event-table thead th', text: 'On behalf of')
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

    it 'renders the timestamp split into date and time, with the full ISO in title' do
      expect(rendered).to have_css('.audit-event__when[title="2026-05-26T12:34:56Z"]')
      expect(rendered).to have_css('.audit-event__when-date', text: '2026-05-26')
      expect(rendered).to have_css('.audit-event__when-time', text: '12:34 UTC')
    end

    it 'renders actor and on-behalf-of NUIDs as monospace chips' do
      expect(rendered).to have_css('.audit-event__nuid', text: '000000002')
    end
  end

  context 'when on_behalf_of_nuid is present' do
    it 'surfaces it as a NUID chip on a per-action row' do
      render_with(events: [event(action: 'create', on_behalf_of: '000000007')])
      expect(rendered).to have_css('.audit-event--create .audit-event__nuid', text: '000000007')
    end

    it 'surfaces it as a NUID chip on the generic row' do
      render_with(events: [event(action: 'mystery_action', on_behalf_of: '000000007')])
      expect(rendered).to have_css('.audit-event--generic .audit-event__nuid', text: '000000007')
    end
  end

  context 'when on_behalf_of_nuid is nil' do
    it 'renders an em-dash placeholder chip' do
      render_with(events: [event(action: 'create')])
      expect(rendered).to have_css('.audit-event--create .audit-event__nuid--empty', text: '—')
    end
  end
end
