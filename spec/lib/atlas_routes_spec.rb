# frozen_string_literal: true

require 'rails_helper'

describe AtlasRoutes do
  describe '.route_for' do
    it 'maps the container and Work types to their own routes' do
      expect(described_class.route_for('Community')).to eq(:community)
      expect(described_class.route_for('Collection')).to eq(:collection)
      expect(described_class.route_for('Work')).to eq(:work)
    end

    # The one pair the two vocabularies disagree on, and the reason the map
    # exists: downcasing would ask for a compilation_path that does not exist.
    it 'maps Atlas Compilation to the UI Set route' do
      expect(described_class.route_for('Compilation')).to eq(:set)
    end

    it 'names the type it was not taught rather than returning a default' do
      expect { described_class.route_for('Sprocket') }
        .to raise_error(ArgumentError, /Sprocket/)
    end

    # Every mapped route has to produce a real show helper, or the map records a
    # name nothing serves.
    it 'names a route that has a path helper' do
      helpers = Rails.application.routes.url_helpers
      described_class::ROUTES.each_value do |route|
        expect(helpers).to respond_to(:"#{route}_path")
      end
    end
  end
end
