# frozen_string_literal: true

module MultipageLoader
  # One item-block from a multipage manifest: its Sequence 0 MODS row plus the
  # ordered page rows that become a single Work. A manifest concatenates many
  # of these (see ItemSet), so `index` is the item's 0-based ordinal in the
  # sheet — the grouping key carried onto each ingest row before a Work exists.
  Item = Struct.new(:index, :rows, keyword_init: true) do
    def mods_row
      rows.find(&:mods_row?)
    end

    def pages
      rows.select(&:page?).sort_by(&:sequence)
    end

    def xml_path
      mods_row&.xml_path
    end

    # Human label for reports and the preview's skipped-item list: the MODS
    # title if present, else the MODS file path, else the first file name.
    def label
      mods_row&.title.presence || xml_path.presence || rows.first&.file_name
    end

    def last_item_present?
      rows.any?(&:last_item?)
    end
  end
end
