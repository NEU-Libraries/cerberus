class CreateGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :groups do |t|
      t.string :raw
      t.string :cosmetic

      t.timestamps
    end
  end
end
