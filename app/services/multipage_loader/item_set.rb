# frozen_string_literal: true

module MultipageLoader
  # Partitions parsed manifest rows into ordered item-blocks. A real manifest
  # concatenates hundreds or thousands of items, each a Sequence 0 MODS row
  # followed by its ordered pages; `Last Item == TRUE` marks an item's final
  # page, so a block runs from after the previous flag through the next
  # flagged row. A trailing run with no closing flag is still returned as an
  # item (Contract reports it as incomplete) rather than silently dropped.
  class ItemSet < ApplicationService
    def initialize(rows:)
      @rows = rows
    end

    def call
      items = []
      block = []
      @rows.each do |row|
        block << row
        next unless row.last_item?

        items << Item.new(index: items.size, rows: block)
        block = []
      end
      items << Item.new(index: items.size, rows: block) if block.any?
      items
    end
  end
end
