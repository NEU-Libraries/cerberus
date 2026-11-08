# frozen_string_literal: true

# Which model an entry in a Work's asset listing is. Atlas names it in `kind`,
# because an embargo nulls a gated Delegate's `uri`, so testing `uri` misreads
# that Delegate as a Blob. See docs/downloads.md.
module AssetKind
  DELEGATE = 'Delegate'

  # Either key: Atlas data is an indifferent Mash, but callers also pass plain
  # symbol-keyed hashes.
  def self.delegate?(asset)
    (asset['kind'] || asset[:kind]).to_s == DELEGATE
  end

  def self.blob?(asset)
    !delegate?(asset)
  end
end
