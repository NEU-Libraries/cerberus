class AddProcessedToImpressions < ActiveRecord::Migration
  def change
    add_column :impressions, :processed, :boolean, :default => false
  end
end
