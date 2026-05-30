# frozen_string_literal: true

class AddIdempotencyAndWarningsToIngests < ActiveRecord::Migration[8.0]
  def change
    %i[iptc_ingests xml_ingests].each do |table|
      add_column table, :idempotency_key, :string
      add_column table, :error_message,   :text
      add_column table, :warnings,        :text, default: '[]'
    end
  end
end
