# frozen_string_literal: true

class AddDerivativesEnabledToSentinels < ActiveRecord::Migration[8.1]
  def change
    # An empty policy already means "clear every tier restriction", so "leave
    # each Work's tiers alone" needs its own flag. True keeps the behaviour every
    # existing Sentinel was saved under.
    add_column :sentinels, :derivatives_enabled, :boolean, default: true, null: false
  end
end
