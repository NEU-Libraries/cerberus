# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HealthCheck do
  let(:probes) { described_class.capabilities.map { |key| :"probe_#{key}" } }

  def stub_all_probes
    probes.each { |probe| allow(described_class).to receive(probe).and_return([true, nil]) }
  end

  it 'reports every capability, in a fixed order' do
    stub_all_probes

    expect(described_class.call(fresh: true).keys).to eq described_class.capabilities
  end

  it 'reports a probe that raises as unavailable, keeping the error for the admin page' do
    stub_all_probes
    allow(described_class).to receive(:probe_search).and_raise(RSolr::Error::ConnectionRefused.new(uri: URI('http://solr:8983/solr/')))

    search = described_class.call(fresh: true)[:search]

    expect(search.status).to eq 'unavailable'
    expect(search.detail).to start_with 'RSolr::Error::ConnectionRefused'
  end

  # One atlas_rb read can outlast Nagios's own timeout with its retries, so a
  # probe that is still waiting is reported down rather than waited for.
  it 'reports a probe that does not answer by the deadline as unavailable' do
    stub_const("#{described_class}::DEADLINE", 0.1)
    stub_all_probes
    allow(described_class).to receive(:probe_records) { sleep 1 }

    records = described_class.call(fresh: true)[:records]

    expect(records.ok).to be false
    expect(records.detail).to start_with 'No answer within'
  end

  describe 'caching' do
    before do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      stub_all_probes
    end

    # The public endpoint is unauthenticated, so without this each request
    # would fan out to every service.
    it 'answers a repeat call from the cache' do
      2.times { described_class.call }

      expect(described_class).to have_received(:probe_search).once
    end

    it 'probes again when asked for a fresh answer' do
      described_class.call
      described_class.call(fresh: true)

      expect(described_class).to have_received(:probe_search).twice
    end
  end

  # The probes that can run against the test stack without a worker or a
  # Cantaloupe behind them.
  describe 'against the test stack' do
    it 'finds the database and the search index answering' do
      results = described_class.call(fresh: true)

      expect(results.values_at(:repository, :search).map(&:status)).to eq %w[ok ok]
    end

    it 'reports an uploads root that is not there' do
      allow(Rails.application.config.x.cerberus).to receive(:slice).and_return(uploads_root: '/nonexistent/uploads')

      uploads = described_class.check(:uploads, fresh: true)

      expect(uploads.ok).to be false
      expect(uploads.detail).to include '/nonexistent/uploads'
    end
  end
end
