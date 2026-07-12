# frozen_string_literal: true

# The per-session Download Queue: a flat list of individually-chosen downloads
# to fetch later as one streamed ZIP. Thin wrapper over the Rails session
# (DB-backed, so no tight cookie cap — but a high sanity bound still guards a
# runaway). Two entry kinds, both string-keyed so session (de)serialization is
# stable and value-equality drives include?/remove:
#
# - content Blob:        `{ 'w' => work_noid, 'b' => blob_noid }`
# - IIIF derivative:     `{ 'w' => work_noid, 'd' => use }` (the S/M/L rendition
#                        `use`, e.g. the same value its download route takes)
#
# The labeled filename + the bytes are fetched at download time, never stored.
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
    items.include?(blob_entry(work_noid, blob_noid))
  end

  def include_derivative?(work_noid, use)
    items.include?(derivative_entry(work_noid, use))
  end

  # @return [Symbol] :ok, :already (no-op duplicate), or :full (cap reached)
  def add(work_noid, blob_noid)
    push(blob_entry(work_noid, blob_noid))
  end

  def add_derivative(work_noid, use)
    push(derivative_entry(work_noid, use))
  end

  def remove(work_noid, blob_noid)
    items.delete(blob_entry(work_noid, blob_noid))
  end

  def remove_derivative(work_noid, use)
    items.delete(derivative_entry(work_noid, use))
  end

  def clear
    @session[:download_queue] = []
  end

  private

    def push(entry)
      return :already if items.include?(entry)
      return :full if count >= MAX

      items << entry
      :ok
    end

    def blob_entry(work_noid, blob_noid)
      { 'w' => work_noid.to_s, 'b' => blob_noid.to_s }
    end

    def derivative_entry(work_noid, use)
      { 'w' => work_noid.to_s, 'd' => use.to_s }
    end
end
