# frozen_string_literal: true

# Finds a Work's existing MP4 rendition of a video or audio original, so a
# replace or revert can update it in place. The rendition is recognized by name,
# not by any Atlas marker; see docs/downloads.md.
class RenditionAsset
  PRIMARY_ROLE = 'original_file'
  MP4 = %w[video/mp4 audio/mp4].freeze

  # @param file_sets [Array<Hash>] AtlasRb::Work.file_sets for the Work.
  # @param mime_types [Array<String>] the rendition's types, such as MP4.
  # @return [Hash, nil] the rendition's asset, or nil when the Work has none.
  def self.for(file_sets, mime_types:)
    originals = Array(file_sets).flat_map { |file_set| Array(file_set['assets']) }
                                .select { |asset| asset['role'].to_s == PRIMARY_ROLE }
    renditions, sources = originals.partition { |asset| mime_types.include?(asset['mime_type']) }
    stems = sources.map { |asset| stem(asset) }

    # min_by: a Work that already holds duplicates must update the same one
    # every time.
    renditions.select { |asset| stems.include?(stem(asset)) }.min_by { |asset| asset['noid'].to_s }
  end

  # original_filename is internal reconciliation only here; never render it.
  def self.stem(asset)
    File.basename(asset['original_filename'].to_s, '.*')
  end
  private_class_method :stem
end
