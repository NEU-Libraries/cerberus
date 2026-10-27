# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Outage do
  def atlas_error(status)
    AtlasRb::ResourceError.new('Atlas said no', response: instance_double(Faraday::Response, status: status, body: ''))
  end

  it 'names a database that will not connect as the whole repository' do
    expect(described_class.for(ActiveRecord::ConnectionNotEstablished.new).key).to eq :repository
  end

  it 'names a Solr that refuses or times out as search' do
    expect(described_class.for(Blacklight::Exceptions::ECONNREFUSED.new).key).to eq :search
    expect(described_class.for(Blacklight::Exceptions::RepositoryTimeout.new).key).to eq :search
  end

  it 'names an Atlas that does not answer as records' do
    expect(described_class.for(Faraday::ConnectionFailed.new('refused')).key).to eq :records
    expect(described_class.for(Faraday::TimeoutError.new).key).to eq :records
  end

  it 'names Atlas reporting its own dependency down as records' do
    error = AtlasRb::BackendUnavailableError.new(code: 'backend_unavailable', dependency: 'storage')

    expect(described_class.for(error).key).to eq :records
  end

  it 'names a gateway status from in front of Atlas as records' do
    expect(described_class.for(atlas_error(503)).key).to eq :records
  end

  # A 500 is as likely to be a bug as an outage. Calling a bug an outage tells
  # the reader to wait for something that will not change.
  it 'leaves an Atlas 500 to the error page' do
    expect(described_class.for(atlas_error(500))).to be_nil
  end

  # Any socket can raise the bare Errno, so it says nothing about Solr.
  it 'leaves a bare connection refusal unclassified' do
    expect(described_class.for(Errno::ECONNREFUSED.new)).to be_nil
  end

  it 'never names a service in what the reader sees' do
    copy = described_class::CAPABILITIES.values.flat_map { |capability| [capability.title, capability.lede] }.join(' ')

    expect(copy).not_to match(/Atlas|Solr|Postgres|Cantaloupe|database|server/i)
  end

  describe '.guard_storage' do
    it 'turns a volume failure into a storage outage, keeping the cause' do
      error = begin
        described_class.guard_storage { raise Errno::EROFS, '/home/cerberus/uploads' }
      rescue described_class::StorageUnavailable => e
        e
      end

      expect(error.cause).to be_a(Errno::EROFS)
      expect(described_class.for(error).key).to eq :uploads
    end

    it 'passes the block value through' do
      expect(described_class.guard_storage { :staged }).to eq :staged
    end
  end
end
