# frozen_string_literal: true

# The user-agent dimension: each distinct UA string recorded once with a derived
# is_bot verdict. Keyed by the UA string (not by event), so it stays tiny
# (thousands of rows) regardless of impression volume — this is the only place a
# bot verdict is materialized, and re-scanning it on a bot-list change is an
# O(distinct-UAs) operation rather than a rewrite of the raw log.
class CreateUserAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :user_agents, id: false do |t|
      t.string :ua_string, null: false
      t.boolean :is_bot, null: false, default: false
      t.datetime :classified_at
    end

    add_index :user_agents, :ua_string, unique: true
  end
end
