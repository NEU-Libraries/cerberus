# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EditTabsHelper do
  # Gates read off the view context's own can? / current_user.
  def allow_gates(history:, loader:)
    allow(helper).to receive(:can?).with(:read, :audit_event).and_return(history)
    allow(helper).to receive(:current_user).and_return(instance_double(User, loader_tier?: loader))
  end

  before { allow_gates(history: true, loader: true) }

  describe '#edit_tab_keys' do
    it 'gives each class its own tab set, in display order' do
      expect(helper.edit_tab_keys('Work'))
        .to eq(%w[metadata advanced permissions move delete xml history])
      expect(helper.edit_tab_keys('Collection'))
        .to eq(%w[metadata permissions xml derivative-access export history analytics])
      expect(helper.edit_tab_keys('Community'))
        .to eq(%w[metadata permissions xml history analytics])
    end

    # Class-specific membership is data, not a conditional, so these are simply
    # absent from the other classes' arrays.
    it 'keeps Analytics container-only and Advanced/Move/Delete Work-only' do
      expect(helper.edit_tab_keys('Work')).not_to include('analytics')
      expect(helper.edit_tab_keys('Collection')).not_to include('advanced', 'move', 'delete')
      expect(helper.edit_tab_keys('Community')).not_to include('derivative-access', 'export')
    end

    it 'drops History for a viewer who cannot read audit events' do
      allow_gates(history: false, loader: true)

      expect(helper.edit_tab_keys('Collection')).not_to include('history')
      expect(helper.edit_tab_keys('Collection')).to include('metadata', 'analytics')
    end

    it 'drops Export for a non-loader' do
      allow_gates(history: true, loader: false)

      expect(helper.edit_tab_keys('Collection')).not_to include('export')
    end

    it 'returns nothing for an unknown class rather than raising' do
      expect(helper.edit_tab_keys('Person')).to eq([])
    end
  end

  describe '#edit_tab_label' do
    it 'humanizes a key by default and special-cases the acronym' do
      expect(helper.edit_tab_label('derivative-access')).to eq('Derivative access')
      expect(helper.edit_tab_label('metadata')).to eq('Metadata')
      expect(helper.edit_tab_label('xml')).to eq('XML')
    end
  end

  describe '#edit_tab_standalone_path' do
    it 'points the XML tab at the XML editor' do
      expect(helper.edit_tab_standalone_path('xml', 'abc123')).to eq('/xml/editor/abc123')
    end

    it 'refuses a key that is not a standalone tab' do
      expect { helper.edit_tab_standalone_path('history', 'abc123') }.to raise_error(ArgumentError)
    end
  end

  # A re-render has to land the reader back on the tab they were working in, and
  # cannot use the URL fragment to do it: Turbo follows a redirect with fetch,
  # which drops the fragment from the resolved URL.
  describe '#edit_tab_open_key' do
    it 'opens the first pane tab when nothing is named' do
      expect(helper.edit_tab_open_key('Collection')).to eq('metadata')
      expect(helper.edit_tab_open_key('Work', open: nil)).to eq('metadata')
    end

    it 'opens the pane a caller names' do
      expect(helper.edit_tab_open_key('Collection', open: 'derivative-access')).to eq('derivative-access')
    end

    it 'falls back to the default for a key this class does not have' do
      expect(helper.edit_tab_open_key('Community', open: 'derivative-access')).to eq('metadata')
      expect(helper.edit_tab_open_key('Collection', open: 'nonsense')).to eq('metadata')
    end

    # A standalone tab links to its own page rather than switching a pane, so
    # opening one would leave the page showing nothing.
    it 'refuses a standalone key' do
      expect(helper.edit_tab_open_key('Collection', open: 'xml')).to eq('metadata')
    end

    # The gates hide whole tabs, and a hidden pane cannot be the open one.
    it 'falls back when the named pane is gated away from this viewer' do
      allow_gates(history: false, loader: false)

      expect(helper.edit_tab_open_key('Collection', open: 'export')).to eq('metadata')
    end
  end

  # The regression this whole module exists to prevent: the XML editor used to
  # hand-mirror this list and silently went stale. Both renderings now read the
  # same declaration, so a new tab cannot reach one and miss the other.
  describe 'single source of truth' do
    it 'derives every pane key from a tab-pane id the edit view actually renders' do
      described_class::TABS.each do |klass, keys|
        view = Rails.root.join("app/views/#{klass.downcase.pluralize}/edit.html.haml").read
        (keys - described_class::STANDALONE).each do |key|
          expect(view).to include("##{key}.tab-pane"),
                          "#{klass} edit view has no ##{key} pane for its declared '#{key}' tab"
        end
      end
    end
  end
end
