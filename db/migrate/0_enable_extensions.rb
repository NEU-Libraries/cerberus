class EnableExtensions < ActiveRecord::Migration[7.2]
  def change
    enable_extension 'uuid-ossp'
    enable_extension 'pgcrypto'
  end
end
