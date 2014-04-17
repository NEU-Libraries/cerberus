class AddIpAddressToDrsImpressions < ActiveRecord::Migration
  def up
    add_column :drs_impressions, :ip_address, :string
  end

  def down
    add_column :drs_impressions, :ip_address, :string
  end
end
