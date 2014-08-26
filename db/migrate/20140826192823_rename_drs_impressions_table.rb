class RenameDrsImpressionsTable < ActiveRecord::Migration
  def up
    rename_table :drs_impressions, :impressions
  end

  def down
    rename_table :impressions, :drs_impressions
  end
end
