class AddNotifiedToXmlAlerts < ActiveRecord::Migration
  def change
    add_column :xml_alerts, :notified, :string
  end
end
