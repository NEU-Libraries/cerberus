class AddUserAgentToImpressions < ActiveRecord::Migration
  def change
    add_column :impressions, :user_agent, :string
  end
end
