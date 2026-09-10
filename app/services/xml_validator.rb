# frozen_string_literal: true

# Phased MODS XML validation. Returns an Array; the document is valid iff it is
# empty. Syntax runs before schema, because unparseable XML cannot be
# schema-validated. Business rules and render checks are deliberately elsewhere
# — see docs/ingest.md.
class XmlValidator < ApplicationService
  def initialize(xml:)
    @xml = xml
  end

  def call
    control_characters = Metadata::ControlCharacters.report(@xml)
    return [control_characters] if control_characters

    syntax_error = parse
    return [syntax_error] if syntax_error

    document_errors + schema_errors
  end

  private

    attr_reader :doc

    def parse
      @doc = Nokogiri::XML(@xml, &:strict)
      nil
    rescue Nokogiri::XML::SyntaxError => e
      e
    end

    def document_errors
      errors = []
      errors << "Document encoding must be UTF-8 (got #{doc.encoding.inspect})" unless doc.encoding == 'UTF-8'
      errors << 'Document must declare xmlns:mods' unless doc.namespaces.key?('xmlns:mods')
      errors
    end

    def schema_errors
      schemas = schema_locations
      return ['Document root must declare a schemaLocation'] if schemas.empty?

      schemas.values.flat_map { |xsd_uri| validate_against(xsd_uri) }
    end

    # kataba raises FetchError for every failure it can name — a non-2xx, a
    # redirect loop, a refused HTTPS->HTTP downgrade, and, as the FetchTimeout
    # subclass, a host that goes quiet. It does not wrap a DNS or connect
    # failure, so those keep their own branch; SystemCallError covers
    # Errno::ECONNREFUSED, Errno::ETIMEDOUT and friends in one.
    #
    # An unfetchable schema is a reportable validation outcome, never a 500:
    # the librarian gets a row saying which schema could not be read.
    def validate_against(xsd_uri)
      Kataba.fetch_schema(xsd_uri).validate(doc)
    rescue Kataba::Fetcher::FetchError, SocketError, SystemCallError => e
      ["Could not fetch schema #{xsd_uri} (#{e.class}: #{e.message})"]
    end

    def schema_locations
      root = doc.root
      return {} unless root

      attr = root.attributes['schemaLocation']
      return {} unless attr

      attr.value.scan(/(\S+)\s+(\S+)/).to_h
    end
end
