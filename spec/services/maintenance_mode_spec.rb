# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MaintenanceMode do
  # The window's state is read from Atlas. Atlas owns enforcement and specs it
  # there; these examples cover the decisions Cerberus makes about the answer.
  def window(read_only:, **attrs)
    AtlasRb::Mash.new({ 'read_only' => read_only }.merge(attrs.transform_keys(&:to_s)))
  end

  before { described_class.reset_cache! }

  describe '.read_only?' do
    it 'is false when Atlas reports an open repository' do
      allow(AtlasRb::Maintenance).to receive(:read).and_return(window(read_only: false))

      expect(described_class.read_only?).to be false
    end

    it 'is true when Atlas reports a window' do
      allow(AtlasRb::Maintenance).to receive(:read).and_return(window(read_only: true))

      expect(described_class.read_only?).to be true
    end
  end

  # Nothing answered at all. That happens while Atlas is being replaced, which
  # is exactly when a window is likely to be open, so hold it.
  describe 'when Atlas does not answer' do
    before { allow(AtlasRb::Maintenance).to receive(:read).and_raise(Faraday::ConnectionFailed.new('down')) }

    it 'treats the repository as read-only' do
      expect(described_class.read_only?).to be true
    end

    it 'offers a message and a retry hint rather than a bare failure' do
      expect(described_class.message).to be_present
      expect(described_class.retry_after).to be_positive
    end
  end

  # Atlas answered, but not with a window — most often a build older than the
  # endpoint. The opposite answer, deliberately: failing closed here would put
  # the whole site into maintenance mode on any Atlas hiccup, and would make
  # Cerberus impossible to deploy ahead of Atlas. Atlas still refuses the write
  # if a window really is open, and the gate's error rescue renders the same
  # page, so the cost of being wrong this way is an ugly error, not lost data.
  describe 'when Atlas answers with something unreadable' do
    before { allow(AtlasRb::Maintenance).to receive(:read).and_raise(JSON::ParserError.new('Puma')) }

    it 'assumes there is no window' do
      expect(described_class.read_only?).to be false
    end
  end

  describe '.open!' do
    it 'names the operator door by default' do
      allow(AtlasRb::Maintenance).to receive(:write).and_return(window(read_only: true))

      described_class.open!(message: 'Back at 10:00', retry_after: 900)

      expect(AtlasRb::Maintenance).to have_received(:write)
        .with(read_only: true, source: 'operator', message: 'Back at 10:00', retry_after: 900)
    end

    it 'carries the deploy door through when the orchestrator is acting' do
      allow(AtlasRb::Maintenance).to receive(:write).and_return(window(read_only: true))

      described_class.open!(source: 'deploy')

      expect(AtlasRb::Maintenance).to have_received(:write)
        .with(hash_including(source: 'deploy'))
    end
  end

  describe '.close!' do
    # Atlas answers a refused deploy-close with 200 and the UNCHANGED state
    # rather than an error, so the only way to know is to read the flag back.
    # Callers that assume the write took would report success wrongly.
    it 'returns the unchanged state when Atlas refuses the close' do
      allow(AtlasRb::Maintenance).to receive(:write)
        .and_return(window(read_only: true, source: 'operator'))

      result = described_class.close!(source: 'deploy')

      expect(result.read_only).to be true
      expect(result.source).to eq 'operator'
    end
  end

  describe 'caching' do
    it 'drops the cached window after a write, so the flipping request sees its own effect' do
      allow(AtlasRb::Maintenance).to receive(:write).and_return(window(read_only: true))
      allow(AtlasRb::Maintenance).to receive(:read).and_return(window(read_only: true))

      described_class.open!
      expect(described_class.read_only?).to be true
    end
  end

  # The contract check. Runs against the live Atlas test instance like the
  # controller specs, so a binding or endpoint drift fails here rather than in
  # a window. It reads only — nothing is opened.
  #
  # A JSON::ParserError here means the running Atlas image predates the
  # endpoint: the response is Puma's HTML error page, not a window. The fix is
  # the image, not this spec — see the failure message.
  describe 'against Atlas' do
    it 'answers the window with the fields Cerberus reads' do
      described_class.reset_cache!

      begin
        state = AtlasRb::Maintenance.read(nuid: '000000004')
      rescue JSON::ParserError
        pinned = Rails.root.join('.atlas_version').read.strip
        raise 'GET /maintenance did not answer JSON. The running Atlas image is older ' \
              "than the endpoint; bring it up to .atlas_version (#{pinned})."
      end

      expect(state).to respond_to(:read_only)
      expect(state.read_only).to be false
    end
  end
end
