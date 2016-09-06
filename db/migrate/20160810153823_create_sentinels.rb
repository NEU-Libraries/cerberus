class CreateSentinels < ActiveRecord::Migration
  def change
    create_table :sentinels do |t|

      t.timestamps
    end
  end
end
