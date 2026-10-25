# frozen_string_literal: true

class CreateNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string   :kind, null: false
      t.string   :title, null: false
      t.string   :body
      t.jsonb    :data, null: false, default: {}
      t.string   :dedupe_key
      t.string   :channels, array: true, null: false, default: []
      t.datetime :read_at
      t.timestamps
    end
    add_index :notifications, %i[user_id created_at]
    add_index :notifications, %i[user_id read_at]
    add_index :notifications, %i[user_id dedupe_key], unique: true, where: "dedupe_key IS NOT NULL"
  end
end
