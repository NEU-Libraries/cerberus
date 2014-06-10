class AddReferrerAndStatusToDrsImpressions < ActiveRecord::Migration
  def change
    add_column :drs_impressions, :referrer, :string
    add_column :drs_impressions, :status, :string
  end
end
