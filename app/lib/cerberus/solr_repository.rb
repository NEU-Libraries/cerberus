# frozen_string_literal: true

module Cerberus
  # Blacklight builds a new repository, and so a new RSolr client and TCP
  # connection, for every catalog search. Sharing one client per process lets
  # the kept-alive adapter named in config/blacklight.yml reuse its connections.
  class SolrRepository < Blacklight::Solr::Repository
    CLIENTS = Concurrent::Map.new

    # The pid is in the key so that a Puma worker never inherits a socket its
    # parent opened before the fork.
    def connection
      @connection ||= CLIENTS.compute_if_absent([Process.pid, connection_config.to_h]) { build_connection }
    end

    private

      # Faraday looks an adapter up by name only when the name is a Symbol, and
      # blacklight.yml cannot hold one: Blacklight parses it with YAML.safe_load.
      def build_connection
        RSolr.connect(connection_config.merge(adapter: connection_config[:http_adapter]&.to_sym))
      end
  end
end
