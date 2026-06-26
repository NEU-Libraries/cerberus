# frozen_string_literal: true

# Parses a single HTTP byte range against a known total size, for the seekable
# media endpoint. Returns nil for an absent / malformed / unsatisfiable range
# (the caller then serves the full 200). Multi-range isn't supported — media
# elements only ever ask for one.
class MediaRange
  Result = Struct.new(:start, :finish, :total, keyword_init: true) do
    def length = finish - start + 1
    def content_range = "bytes #{start}-#{finish}/#{total}"
  end

  def self.parse(header, total)
    total = total.to_i
    match = header.to_s.match(/\Abytes=(\d*)-(\d*)\z/)
    return nil if total.zero? || match.nil?

    start, finish = bounds(match[1], match[2], total)
    return nil if start.nil? || start > finish || start >= total

    Result.new(start: start, finish: finish, total: total)
  end

  # @return [Array(Integer, Integer), Array(nil, nil)] inclusive [start, finish],
  #   or [nil, nil] for an empty `bytes=-` range.
  def self.bounds(start_str, end_str, total)
    return [nil, nil] if start_str.empty? && end_str.empty?
    return [[total - end_str.to_i, 0].max, total - 1] if start_str.empty? # bytes=-SUFFIX

    [start_str.to_i, end_str.empty? ? total - 1 : [end_str.to_i, total - 1].min]
  end
end
