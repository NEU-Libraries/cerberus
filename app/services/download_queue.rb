# frozen_string_literal: true

# The per-session Download Queue: a flat list of individually-chosen content
# Blobs to download later as one streamed ZIP. Thin wrapper over the Rails
# session (DB-backed, so no tight cookie cap — but a high sanity bound still
# guards a runaway). Entries are minimal `{ 'w' => work_noid, 'b' => blob_noid }`
# pairs (string keys, so session (de)serialization is stable); the labeled
# filename + the bytes are fetched at download time, never stored here.
class DownloadQueue
  MAX = 1_000

  def initialize(session)
    @session = session
  end

  def items
    @session[:download_queue] ||= []
  end

  def count
    items.size
  end

  delegate :empty?, to: :items

  def include?(work_noid, blob_noid)
    items.include?(entry(work_noid, blob_noid))
  end

  # @return [Symbol] :ok, :already (no-op duplicate), or :full (cap reached)
  def add(work_noid, blob_noid)
    return :already if include?(work_noid, blob_noid)
    return :full if count >= MAX

    items << entry(work_noid, blob_noid)
    :ok
  end

  def remove(work_noid, blob_noid)
    items.delete(entry(work_noid, blob_noid))
  end

  def clear
    @session[:download_queue] = []
  end

  private

    def entry(work_noid, blob_noid)
      { 'w' => work_noid.to_s, 'b' => blob_noid.to_s }
    end
end
