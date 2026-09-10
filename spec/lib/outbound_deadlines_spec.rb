# frozen_string_literal: true

require 'rails_helper'

# The rule this file exists to keep: **every outbound call a request can make
# carries a deadline.**
#
# None of these clients sets one by default. Faraday falls through to
# Net::HTTP's 60s, RSolr forwards a timeout only when given one, and a bare
# `Faraday.get` inherits the same 60s — so an unset pair is not "the library's
# sensible default", it is a minute of a Puma thread per call. Puma has no
# request timeout and there is no rack-timeout, so the client is the only place
# the bound can live. See docs/development.md.
#
# Asserted on the connection rather than on the config file, because the config
# only matters if it arrives: RSolr silently ignores an option it does not
# recognise, and `read_timeout` (deprecated in RSolr 2.6, gone in 3) is exactly
# the shape of mistake that looks right in YAML and sets nothing.
describe 'outbound deadlines' do
  describe 'Solr, via Blacklight' do
    let(:options) do
      Blacklight::Solr::Repository.new(CatalogController.blacklight_config).connection.connection.options
    end

    it 'bounds the connect' do
      expect(options.open_timeout).to eq(2)
    end

    it 'bounds the response' do
      expect(options.timeout).to eq(10)
    end
  end

  describe 'Atlas, via atlas_rb' do
    # Set by the gem, not by us — the initializer leaves them at the gem's
    # defaults deliberately. Pinned here so a gem bump that dropped them, or
    # raised them back towards a minute, fails a spec rather than going unnoticed.
    it 'bounds the connect' do
      expect(AtlasRb::Transport.open_timeout).to be_between(1, 5)
    end

    it 'bounds the response' do
      expect(AtlasRb::Transport.read_timeout).to be_between(5, 15)
    end
  end

  # Asserted on the constants rather than a connection: this one is a per-call
  # `Faraday.get` with request-scoped options, so there is no long-lived
  # connection to interrogate. Naming them is what keeps this file the one
  # inventory of every deadline.
  describe 'Cantaloupe, via IiifManifest' do
    it 'bounds the connect' do
      expect(IiifManifest::INFO_OPEN_TIMEOUT).to be_between(1, 5)
    end

    it 'bounds the response' do
      expect(IiifManifest::INFO_READ_TIMEOUT).to be_between(2, 15)
    end
  end

  describe 'the XSD schema host, via kataba' do
    it 'bounds the connect' do
      expect(Kataba.configuration.open_timeout).to eq(3)
    end

    it 'bounds the response' do
      expect(Kataba.configuration.read_timeout).to eq(10)
    end
  end
end
