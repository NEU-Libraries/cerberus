# frozen_string_literal: true

# Wraps a single content Blob in a streamed zip — the one-file degenerate of
# SetZipPacker/QueueZipPacker. DownloadsController uses it for `generic` blobs
# (content Atlas could not identify): rather than streaming raw bytes, the
# browser receives an inert archive to save. The UI already labels these "Zip
# File", and wrapping keeps a browser from trying to render/execute an unknown
# binary inline.
#
# The lone entry sits at the archive root (nil folder) and carries no
# MANIFEST.txt — the per-work folder and manifest only earn their place in the
# multi-file packers. STORE compression and the labeled entry naming come from
# {ZipEntryWriter}, shared so single- and bulk-file downloads can't drift.
class BlobZipPacker
  include ZipEntryWriter

  # @param asset [AtlasRb::Mash] the Work.assets entry for the blob (already
  #   resolved and authorized by the download controller's derivative gate).
  def initialize(asset:)
    @asset = asset
  end

  # @param zip [ZipKit::Streamer] an open writer (from `zip_kit_stream`)
  # @return [void]
  def pack(zip)
    write_asset(zip, nil, @asset, [], [])
  end
end
