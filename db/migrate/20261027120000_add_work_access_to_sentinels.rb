# frozen_string_literal: true

class AddWorkAccessToSentinels < ActiveRecord::Migration[8.1]
  def change
    # Nullable on purpose: no row means the Sentinel leaves each Work's own ACL
    # alone, which is every Sentinel written before this column existed.
    add_column :sentinels, :work_access, :jsonb
  end
end
