# frozen_string_literal: true

class CreateGoals < ActiveRecord::Migration[7.0]
  def change
    create_table :goals, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.references :category, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.decimal :target_amount, precision: 10, scale: 2, null: false
      t.decimal :current_amount, precision: 10, scale: 2, null: false, default: 0
      t.date :deadline
      t.string :status, null: false, default: "active"
      t.text :notes
      t.datetime :achieved_at

      t.timestamps
    end

    add_index :goals, [:user_id, :status]
  end
end
