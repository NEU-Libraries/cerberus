class AddImageFileToIptcIngests < ActiveRecord::Migration[7.2]
  def change
    add_column :iptc_ingests, :image_file, :binary
  end
end
