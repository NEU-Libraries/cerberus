# frozen_string_literal: true

# Phased MODS XML validation.
#
# Runs syntactic checks first; if the document is unparseable, schema
# checks are skipped (you can't schema-validate XML that doesn't parse).
# Returns an Array; the document is valid iff the array is empty. Errors
# stringify cleanly for display (Nokogiri::XML::SyntaxError responds to
# to_s, and the rest are plain strings).
#
# Phase 3 (business rules — required fields, date formats) is intentionally
# omitted at this layer. Different consumers (XML editor, IPTC ingest,
# future bulk loaders) want different rule sets; layering them on top of
# this generic XSD-floor validator keeps each consumer's contract narrow.
#
# Phase 4 (does the MODS-display partial actually render?) is handled by
# the caller via AtlasRb::Resource.preview, since rendering lives Atlas-side.
class XmlValidator < ApplicationService
  def initialize(xml:)
    @xml = xml
  end

  def call
    begin
      @doc = Nokogiri::XML(@xml) { |config| config.strict }
    rescue Nokogiri::XML::SyntaxError => e
      return [e]
    end

    errors = []
    errors << "Document encoding must be UTF-8 (got #{@doc.encoding.inspect})" unless @doc.encoding == "UTF-8"
    errors << "Document must declare xmlns:mods" unless @doc.namespaces.key?("xmlns:mods")

    schemas = schema_locations
    if schemas.empty?
      errors << "Document root must declare a schemaLocation"
    else
      schemas.each_value do |xsd_uri|
        errors.concat(Kataba.fetch_schema(xsd_uri).validate(@doc))
      end
    end

    errors
  end

  private

    def schema_locations
      attr = @doc.root&.attributes&.[]("schemaLocation")&.value
      return {} unless attr
      attr.scan(/(\S+)\s+(\S+)/).to_h
    end
end
