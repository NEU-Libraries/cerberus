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
    it 'renders nothing — no table, no atlas_rb call' do
      allow(view).to receive(:can?).with(:read, :audit_event).and_return(false)
      expect(AtlasRb::Resource).not_to receive(:history)
      render partial: 'audit_events/history', locals: { resource_id: resource_id }
      expect(rendered).to be_blank
    end
  end

  context 'when the user can read audit events but the history is empty' do
    it 'renders an empty-state message and no table' do
      render_with(events: [])
      expect(rendered).to include('No recorded events.')
      expect(rendered).not_to have_css('table.audit-event-table')
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

    it 'renders a Bootstrap table with column headers' do
      expect(rendered).to have_css('table.audit-event-table thead th', text: 'When')
      expect(rendered).to have_css('table.audit-event-table thead th', text: 'Action')
      expect(rendered).to have_css('table.audit-event-table thead th', text: 'Actor')
      expect(rendered).to have_css('table.audit-event-table thead th', text: 'On behalf of')
    end

    it 'renders the create/update/tombstone/restore badges' do
      expect(rendered).to have_css('span.badge.bg-success', text: 'Created')
      expect(rendered).to have_css('span.badge.bg-primary', text: 'Updated')
      expect(rendered).to have_css('span.badge.bg-danger', text: 'Tombstoned')
      expect(rendered).to have_css('span.badge.bg-warning', text: 'Restored')
    end

    it 'falls back to the generic badge for unknown action types' do
      expect(rendered).to have_css('span.badge.bg-secondary', text: 'mystery_action')
    end

    it 'renders the action-typed tr classes and the formatted timestamp + actor in cells' do
      expect(rendered).to have_css('tr.audit-event.audit-event--create')
      expect(rendered).to have_css('tr.audit-event.audit-event--update')
      expect(rendered).to have_css('tr.audit-event.audit-event--tombstone')
      expect(rendered).to have_css('tr.audit-event.audit-event--restore')
      expect(rendered).to include('2026-05-26 12:34 UTC')
      expect(rendered).to include('000000002')
    end
  end

  context 'when on_behalf_of_nuid is present' do
    it 'surfaces it in a per-action row' do
      render_with(events: [event(action: 'create', on_behalf_of: '000000007')])
      expect(rendered).to have_css('tr.audit-event--create td', text: '000000007')
    end

    it 'surfaces it in the generic row' do
      render_with(events: [event(action: 'mystery_action', on_behalf_of: '000000007')])
      expect(rendered).to have_css('tr.audit-event td', text: '000000007')
    end
  end

  context 'when on_behalf_of_nuid is nil' do
    it 'renders an em-dash placeholder' do
      render_with(events: [event(action: 'create')])
      expect(rendered).to have_css('tr.audit-event--create td.text-muted', text: '—')
    end
  end
end
