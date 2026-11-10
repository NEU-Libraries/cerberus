# frozen_string_literal: true

require 'rails_helper'

describe Cerberus::SolrRepository do
  let(:config) { CatalogController.blacklight_config }

  it 'is the repository both Blacklight entry points use' do
    expect(config.repository).to be_a(described_class)
    expect(Blacklight.default_index).to be_a(described_class)
  end

  it 'shares one client between the repositories a catalog search builds' do
    expect(config.repository.connection).to be(config.repository.connection)
  end

  it 'shares that client with Blacklight.default_index' do
    expect(config.repository.connection).to be(Blacklight.default_index.connection)
  end

  it 'keeps connections alive' do
    adapter = config.repository.connection.connection.builder.adapter
    expect(adapter.klass).to eq(Faraday::Adapter::NetHttpPersistent)
  end

  it 'builds a separate client for a different Solr' do
    other = Blacklight::Configuration.new(connection_config: config.connection_config.merge(url: 'http://elsewhere:8983/solr/x'))
    expect(described_class.new(other).connection).not_to be(config.repository.connection)
  end

  it 'builds a separate client after a fork' do
    shared = config.repository.connection
    allow(Process).to receive(:pid).and_return(Process.pid + 1)
    expect(config.repository.connection).not_to be(shared)
  end
end
