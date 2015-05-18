class CreateImageReports < ActiveRecord::Migration
  def change
    create_table :image_reports do |t|
      t.boolean :valid
      t.string :pid
      t.string :collection
      t.string :name
      t.string :email
      t.string :title
      t.text   :iptc
      t.text   :exception


      t.timestamps
    end
  end
end
