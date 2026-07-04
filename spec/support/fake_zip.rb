# frozen_string_literal: true

# Minimal stand-in for zip_kit's writer, shared by the packer specs: records
# each stored entry's name and the bytes pushed into its sink. Only responds to
# write_stored_file, so a regression to write_file/write_deflated_file (losing
# STORE) fails loudly here rather than silently re-compressing.
class FakeZip
  Entry = Struct.new(:name, :body)

  attr_reader :entries

  def initialize = @entries = []

  def write_stored_file(name)
    sink = +''
    yield sink
    entries << Entry.new(name, sink)
  end
end
