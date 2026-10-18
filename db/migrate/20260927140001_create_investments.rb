# frozen_string_literal: true

class CreateInvestments < ActiveRecord::Migration[7.0]
  def change
    create_table :investments, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false
      t.string :asset_type, null: false, default: "other"
      t.string :institution
      t.decimal :invested_amount, precision: 10, scale: 2, null: false
      t.decimal :current_amount, precision: 10, scale: 2, null: false, default: 0
      t.date :invested_on, null: false
      t.string :status, null: false, default: "active"
      t.text :notes

      t.timestamps
    end

    add_index :investments, [:user_id, :status]
    add_index :investments, [:user_id, :asset_type]
  end
end
