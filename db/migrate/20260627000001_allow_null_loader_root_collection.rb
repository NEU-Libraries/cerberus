# frozen_string_literal: true

# root_collection is now required only for IPTC loaders (the safety rail that
# boxes non-librarian operators into a pre-blessed subtree). XML and multipage
# loaders are librarian-operated and pick any destination collection at upload
# time, so they need no root collection at all — relax the NOT NULL constraint
# and let the model enforce presence conditionally.
class AllowNullLoaderRootCollection < ActiveRecord::Migration[8.1]
  def change
    change_column_null :loaders, :root_collection, true
  end
end
