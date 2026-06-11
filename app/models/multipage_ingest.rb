# frozen_string_literal: true

# One row per *page* of a multipage Work (unlike XmlIngest's one row per
# manifest row): the report view's per-row UX maps to pages. All rows of a
# LoadReport share one work_pid — the single Work the archive becomes.
class MultipageIngest < Ingest
end
