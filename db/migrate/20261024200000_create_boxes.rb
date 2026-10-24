# frozen_string_literal: true

class CreateBoxes < ActiveRecord::Migration[7.0]
  def change
    create_table :boxes, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string  :name, null: false
      t.string  :kind, null: false, default: "custom"
      t.string  :illustration_key, null: false, default: "piggy"
      t.string  :color
      t.decimal :target_amount, precision: 10, scale: 2
      t.decimal :balance, precision: 12, scale: 2, null: false, default: 0
      t.integer :position, null: false, default: 0
      t.text    :notes
      t.datetime :archived_at
      t.timestamps
    end
    add_index :boxes, %i[user_id archived_at position]

    create_table :box_movements, id: :uuid do |t|
      t.references :box,  type: :uuid, null: false, foreign_key: true
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :transaction, type: :uuid, foreign_key: { to_table: :transactions }
      t.string  :kind, null: false
      t.string  :source, null: false, default: "manual"
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.decimal :balance_after, precision: 12, scale: 2, null: false
      t.string  :description
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :box_movements, %i[box_id occurred_at]
    add_index :box_movements, %i[user_id occurred_at]
    add_index :box_movements, %i[transaction_id box_id], unique: true, where: "transaction_id IS NOT NULL"
  end
end
