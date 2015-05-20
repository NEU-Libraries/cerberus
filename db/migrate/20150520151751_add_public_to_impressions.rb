class AddPublicToImpressions < ActiveRecord::Migration
  def change
    add_column :impressions, :public, :boolean, :default => false
  end
end
