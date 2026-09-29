# frozen_string_literal: true

# Finds a Work's existing PDF rendition, so a replace or revert can update it
# in place. The rendition is recognized by name, not by any Atlas marker; see
# docs/downloads.md.
class PdfRenditionAsset
  PRIMARY_ROLE = 'original_file'
  PDF          = 'application/pdf'

  # @param file_sets [Array<Hash>] AtlasRb::Work.file_sets for the Work.
  # @return [Hash, nil] the rendition's asset, or nil when the Work has none.
  def self.for(file_sets)
    originals = Array(file_sets).flat_map { |file_set| Array(file_set['assets']) }
                                .select { |asset| asset['role'].to_s == PRIMARY_ROLE }
    pdfs, sources = originals.partition { |asset| asset['mime_type'] == PDF }
    stems = sources.map { |asset| stem(asset) }

    # min_by: a Work that already holds duplicates must update the same one
    # every time.
    pdfs.select { |asset| stems.include?(stem(asset)) }.min_by { |asset| asset['noid'].to_s }
  end

  # original_filename is internal reconciliation only here; never render it.
  def self.stem(asset)
    File.basename(asset['original_filename'].to_s, '.*')
  end
  private_class_method :stem
end
