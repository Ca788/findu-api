# frozen_string_literal: true

class CreateDeviceTokens < ActiveRecord::Migration[7.0]
  def change
    create_table :device_tokens, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string   :token, null: false
      t.string   :platform, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end
    add_index :device_tokens, :token, unique: true
  end
end
