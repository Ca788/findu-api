# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_10_25_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.uuid "record_id", null: false
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "artifacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "artifact_type", null: false
    t.string "source"
    t.jsonb "raw_data", default: {}
    t.jsonb "processed_data", default: {}
    t.string "status", default: "pending"
    t.datetime "occurred_at"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_artifacts_on_status"
    t.index ["user_id"], name: "index_artifacts_on_user_id"
  end

  create_table "box_movements", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "box_id", null: false
    t.uuid "user_id", null: false
    t.uuid "transaction_id"
    t.string "kind", null: false
    t.string "source", default: "manual", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.decimal "balance_after", precision: 12, scale: 2, null: false
    t.string "description"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["box_id", "occurred_at"], name: "index_box_movements_on_box_id_and_occurred_at"
    t.index ["box_id"], name: "index_box_movements_on_box_id"
    t.index ["transaction_id", "box_id"], name: "index_box_movements_on_transaction_id_and_box_id", unique: true, where: "(transaction_id IS NOT NULL)"
    t.index ["transaction_id"], name: "index_box_movements_on_transaction_id"
    t.index ["user_id", "occurred_at"], name: "index_box_movements_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_box_movements_on_user_id"
  end

  create_table "boxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.string "kind", default: "custom", null: false
    t.string "illustration_key", default: "piggy", null: false
    t.string "color"
    t.decimal "target_amount", precision: 10, scale: 2
    t.decimal "balance", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "position", default: 0, null: false
    t.text "notes"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "archived_at", "position"], name: "index_boxes_on_user_id_and_archived_at_and_position"
    t.index ["user_id"], name: "index_boxes_on_user_id"
  end

  create_table "budgets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.decimal "limit_amount", precision: 10, scale: 2
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "period_type", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.index ["period_type"], name: "index_budgets_on_period_type"
    t.index ["user_id", "period_start", "period_end"], name: "index_budgets_on_user_id_and_period", unique: true
    t.index ["user_id"], name: "index_budgets_on_user_id"
  end

  create_table "categories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.string "whatsapp"
    t.index ["user_id"], name: "index_categories_on_user_id"
  end

  create_table "chat_conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "title"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "agent_id"
    t.string "model_id"
    t.index ["agent_id"], name: "index_chat_conversations_on_agent_id"
    t.index ["model_id"], name: "index_chat_conversations_on_model_id"
    t.index ["user_id"], name: "index_chat_conversations_on_user_id"
  end

  create_table "chat_messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "conversation_id", null: false
    t.uuid "user_id", null: false
    t.uuid "parent_message_id"
    t.string "role", null: false
    t.string "kind", default: "text", null: false
    t.text "body"
    t.string "status", default: "pending", null: false
    t.string "intent"
    t.jsonb "payload", default: {}
    t.jsonb "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "client_message_id"
    t.datetime "deleted_at"
    t.index ["conversation_id"], name: "index_chat_messages_on_conversation_id"
    t.index ["deleted_at"], name: "index_chat_messages_on_deleted_at"
    t.index ["parent_message_id"], name: "index_chat_messages_on_parent_message_id"
    t.index ["role"], name: "index_chat_messages_on_role"
    t.index ["status"], name: "index_chat_messages_on_status"
    t.index ["user_id", "client_message_id"], name: "index_chat_messages_on_user_and_client_message_id", unique: true, where: "(client_message_id IS NOT NULL)"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "device_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "token", null: false
    t.string "platform", null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_device_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_device_tokens_on_user_id"
  end

  create_table "goals", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "category_id"
    t.string "name", null: false
    t.decimal "target_amount", precision: 10, scale: 2, null: false
    t.decimal "current_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.date "deadline"
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "achieved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_goals_on_category_id"
    t.index ["user_id", "status"], name: "index_goals_on_user_id_and_status"
    t.index ["user_id"], name: "index_goals_on_user_id"
  end

  create_table "insights", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "reference_type", null: false
    t.uuid "reference_id"
    t.text "content"
    t.string "severity"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reference_type"], name: "index_insights_on_reference_type"
    t.index ["user_id"], name: "index_insights_on_user_id"
  end

  create_table "installment_plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.decimal "total_amount", precision: 10, scale: 2
    t.integer "total_installments"
    t.integer "current_installment"
    t.decimal "monthly_amount", precision: 10, scale: 2
    t.datetime "started_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id"
    t.uuid "category_id"
    t.string "description"
    t.string "transaction_type", default: "expense", null: false
    t.date "first_competency"
    t.string "status", default: "active", null: false
    t.datetime "canceled_at"
    t.index ["category_id"], name: "index_installment_plans_on_category_id"
    t.index ["user_id", "status"], name: "index_installment_plans_on_user_id_and_status"
    t.index ["user_id"], name: "index_installment_plans_on_user_id"
  end

  create_table "investments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "name", null: false
    t.string "asset_type", default: "other", null: false
    t.string "institution"
    t.decimal "invested_amount", precision: 10, scale: 2, null: false
    t.decimal "current_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.date "invested_on", null: false
    t.string "status", default: "active", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "asset_type"], name: "index_investments_on_user_id_and_asset_type"
    t.index ["user_id", "status"], name: "index_investments_on_user_id_and_status"
    t.index ["user_id"], name: "index_investments_on_user_id"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "kind", null: false
    t.string "title", null: false
    t.string "body"
    t.jsonb "data", default: {}, null: false
    t.string "dedupe_key"
    t.string "channels", default: [], null: false, array: true
    t.datetime "read_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "created_at"], name: "index_notifications_on_user_id_and_created_at"
    t.index ["user_id", "dedupe_key"], name: "index_notifications_on_user_id_and_dedupe_key", unique: true, where: "(dedupe_key IS NOT NULL)"
    t.index ["user_id", "read_at"], name: "index_notifications_on_user_id_and_read_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "receipts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "payer_name"
    t.string "payer_phone", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0", null: false
    t.string "status", default: "pending", null: false
    t.datetime "sent_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "category_id"
    t.index ["category_id"], name: "index_receipts_on_category_id"
    t.index ["status"], name: "index_receipts_on_status"
    t.index ["user_id", "created_at"], name: "index_receipts_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_receipts_on_user_id"
  end

  create_table "recurrence_rules", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "category_id"
    t.string "transaction_type", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "description"
    t.string "frequency", default: "monthly", null: false
    t.integer "day_of_month"
    t.date "starts_on", null: false
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.datetime "canceled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_recurrence_rules_on_category_id"
    t.index ["user_id", "active"], name: "index_recurrence_rules_on_user_id_and_active"
    t.index ["user_id"], name: "index_recurrence_rules_on_user_id"
  end

  create_table "refresh_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "token_digest", null: false
    t.uuid "family_id", null: false
    t.string "client"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id", "family_id"], name: "index_refresh_tokens_on_user_id_and_family_id"
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "transactions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "artifact_id"
    t.uuid "category_id"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "transaction_type", null: false
    t.string "description"
    t.datetime "occurred_at"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "competency_month", null: false
    t.string "status", default: "pending", null: false
    t.datetime "paid_at"
    t.integer "installment_number"
    t.uuid "recurrence_rule_id"
    t.uuid "installment_plan_id"
    t.string "payer_name"
    t.string "payer_phone"
    t.index ["artifact_id"], name: "index_transactions_on_artifact_id"
    t.index ["category_id"], name: "index_transactions_on_category_id"
    t.index ["installment_plan_id"], name: "index_transactions_on_installment_plan_id"
    t.index ["recurrence_rule_id"], name: "index_transactions_on_recurrence_rule_id"
    t.index ["user_id", "competency_month"], name: "index_transactions_on_user_id_and_competency_month"
    t.index ["user_id", "payer_phone"], name: "index_transactions_on_user_id_and_payer_phone"
    t.index ["user_id", "status"], name: "index_transactions_on_user_id_and_status"
    t.index ["user_id"], name: "index_transactions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.jsonb "settings", default: {}
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.string "jti", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "artifacts", "users"
  add_foreign_key "box_movements", "boxes"
  add_foreign_key "box_movements", "transactions"
  add_foreign_key "box_movements", "users"
  add_foreign_key "boxes", "users"
  add_foreign_key "budgets", "users"
  add_foreign_key "categories", "users"
  add_foreign_key "chat_conversations", "users"
  add_foreign_key "chat_messages", "chat_conversations", column: "conversation_id"
  add_foreign_key "chat_messages", "chat_messages", column: "parent_message_id"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "device_tokens", "users"
  add_foreign_key "goals", "categories"
  add_foreign_key "goals", "users"
  add_foreign_key "insights", "users"
  add_foreign_key "installment_plans", "categories"
  add_foreign_key "installment_plans", "users"
  add_foreign_key "investments", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "receipts", "categories"
  add_foreign_key "receipts", "users"
  add_foreign_key "recurrence_rules", "categories"
  add_foreign_key "recurrence_rules", "users"
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "transactions", "artifacts"
  add_foreign_key "transactions", "categories"
  add_foreign_key "transactions", "installment_plans"
  add_foreign_key "transactions", "recurrence_rules"
  add_foreign_key "transactions", "users"
end
