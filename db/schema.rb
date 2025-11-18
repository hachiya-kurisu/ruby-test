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

ActiveRecord::Schema[8.1].define(version: 2025_11_18_114030) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "subscription_events", force: :cascade do |t|
    t.integer "amount_cents"
    t.string "amount_currency", default: "JPY"
    t.datetime "created_at", precision: nil, null: false
    t.integer "event_type", null: false
    t.datetime "expires_date"
    t.datetime "failed_at"
    t.datetime "processed_at"
    t.string "product_id"
    t.datetime "purchase_date"
    t.jsonb "raw_payload", default: {}, null: false
    t.bigint "subscription_id", null: false
    t.string "transaction_id", null: false
    t.index ["created_at"], name: "index_subscription_events_on_created_at"
    t.index ["event_type"], name: "index_subscription_events_on_event_type"
    t.index ["failed_at"], name: "index_subscription_events_on_failed_at"
    t.index ["processed_at"], name: "index_subscription_events_on_processed_at"
    t.index ["subscription_id"], name: "index_subscription_events_on_subscription_id"
    t.index ["transaction_id", "event_type", "purchase_date"], name: "index_subscription_events_on_idempotency_key", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.string "product_id", null: false
    t.integer "status", default: 0, null: false
    t.string "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_current_active_subscription", unique: true, where: "(status = ANY (ARRAY[0, 1]))"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "subscription_events", "subscriptions", on_delete: :restrict
  add_foreign_key "subscriptions", "users", on_delete: :restrict
end
