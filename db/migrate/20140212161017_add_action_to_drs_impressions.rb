class AddActionToDrsImpressions < ActiveRecord::Migration
  def change
    add_column :drs_impressions, :action, :string
  end
end
