class SetViewPrefDefault < ActiveRecord::Migration
  def up
    change_column :users, :view_pref, :string, default: 'list' 
  end

  def down
    # Need to execute custom SQL to set default back to nil. 
  end
end
