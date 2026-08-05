# frozen_string_literal: true

require 'rails_helper'

# The contract between MetadataExportPacker and the two resolvers that feed it.
#
# The packer reads fields off each Solr doc; a resolver decides which fields Solr
# is asked for. Nothing connects the two at runtime, and a mismatch raises
# NOTHING — the doc simply has no value for the missing field, so the manifest
# gets a blank cell that reads as "nothing to say".
#
# That is how the collection export came to blank the Embargoed? / Embargo Date
# columns while a set export of the same Work filled them, and because a manifest
# row carrying a PID *updates* that record, a re-load then cleared an embargo
# nobody had touched. These examples assert the coverage rather than any one
# field name, so the next field the packer learns to read is caught too.
RSpec.describe 'export Solr field contract' do
  # A builder that records the `fl` it is asked to merge, so the query can be
  # inspected without standing up Solr.
  class FlRecorder
    attr_reader :fl

    def with(*) = self
    def with_filters(*) = self

    def merge(**extra)
      @fl = extra[:fl] if extra.key?(:fl)
      self
    end
  end

  # Drive a resolver's paging loop once and return the fields it asked Solr for.
  def captured_fl(resolver)
    builder = FlRecorder.new
    allow(Blacklight.default_index).to receive(:search)
      .and_return(instance_double(Blacklight::Solr::Response, documents: []))

    resolver.call(instance_double(Blacklight::SearchService, search_builder: builder))
            .each_content_batch { |_docs| nil }
    builder.fl.to_s.split(',')
  end

  it 'has the packer declare every field it reads' do
    # Guards the declaration itself: the embargo columns are computed from these.
    expect(MetadataExportPacker::REQUIRED_DOC_FIELDS)
      .to include('embargo_release_date_dtsi', 'embargoed_bsi', 'alternate_ids_ssim')
  end

  it 'asks Solr for every field the packer reads, on the COLLECTION path' do
    asked = captured_fl(->(svc) { CollectionContentsResolver.new(valkyrie_id: 'uuid-1', search_service: svc) })

    expect(asked).to include(*MetadataExportPacker::REQUIRED_DOC_FIELDS)
  end

  it 'asks Solr for every field the packer reads, on the SET path' do
    asked = SetResolver::PACKER_FIELDS.split(',')

    expect(asked).to include(*MetadataExportPacker::REQUIRED_DOC_FIELDS)
  end

  # The set path feeds the content download as well as the manifest, so its field
  # list has to satisfy both packers — asking for only one packer's fields is how
  # the embargo gate previously read nil on every document.
  it 'also covers the download packer on the SET path' do
    asked = SetResolver::PACKER_FIELDS.split(',')

    expect(asked).to include(*SetZipPacker::REQUIRED_DOC_FIELDS)
  end
end
