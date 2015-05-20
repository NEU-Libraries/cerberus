class AddTimestampToImpression < ActiveRecord::Migration
  def change
    change_table(:impressions) { |t| t.timestamps }
  end
end
