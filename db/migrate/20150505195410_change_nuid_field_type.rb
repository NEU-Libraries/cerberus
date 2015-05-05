class ChangeNuidFieldType < ActiveRecord::Migration
  def self.up
      change_table :load_reports do |t|
        t.change :nuid, :string
      end
    end
    def self.down
      change_table :load_reports do |t|
        t.change :nuid, :integer
      end
    end
end
