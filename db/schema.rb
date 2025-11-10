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

ActiveRecord::Schema[7.2].define(version: 2025_11_10_131433) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "inboxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "unread_count", default: 0, null: false
    t.index ["unread_count"], name: "idx_inboxes_unread_count"
    t.index ["user_id"], name: "index_inboxes_on_user_id"
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.uuid "outbox_id"
    t.uuid "inbox_id"
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 0, null: false
    t.integer "routing_type", default: 0, null: false
    t.uuid "parent_message_id"
    t.datetime "read_at"
    t.uuid "prescription_id"
    t.index ["inbox_id", "created_at"], name: "idx_messages_inbox_created_at", order: { created_at: :desc }
    t.index ["inbox_id", "prescription_id", "created_at"], name: "idx_messages_inbox_prescription_created"
    t.index ["inbox_id", "read", "created_at"], name: "idx_messages_inbox_unread_created", order: { created_at: :desc }
    t.index ["inbox_id", "read_at"], name: "idx_messages_inbox_unread", where: "(read_at IS NULL)"
    t.index ["outbox_id", "created_at"], name: "idx_messages_outbox_created_at", order: { created_at: :desc }
    t.index ["parent_message_id", "created_at"], name: "idx_messages_parent_thread", order: { created_at: :desc }
    t.index ["parent_message_id", "created_at"], name: "idx_messages_root_conversations", order: { created_at: :desc }, where: "(parent_message_id IS NULL)"
    t.index ["prescription_id", "created_at"], name: "index_messages_on_prescription_id_and_created_at"
    t.index ["prescription_id"], name: "index_messages_on_prescription_id"
    t.index ["routing_type", "created_at"], name: "index_messages_on_routing_type_and_created_at"
    t.index ["routing_type"], name: "index_messages_on_routing_type"
    t.index ["status", "created_at"], name: "index_messages_on_status_and_created_at"
    t.index ["status", "read"], name: "idx_messages_status_read"
  end

  create_table "outboxes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_outboxes_on_user_id"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "amount", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "status", default: 0, null: false
    t.string "payment_provider", default: "flaky", null: false
    t.text "error_message"
    t.integer "retry_count", default: 0, null: false
    t.datetime "last_retry_at"
    t.index ["retry_count"], name: "index_payments_on_retry_count"
    t.index ["status", "created_at"], name: "index_payments_on_status_and_created_at"
    t.index ["status", "retry_count", "created_at"], name: "idx_payments_status_retry_created"
    t.index ["user_id", "status", "created_at"], name: "idx_payments_user_status_created"
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "prescriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.integer "status", default: 0, null: false
    t.string "pdf_url"
    t.datetime "requested_at", null: false
    t.datetime "ready_at"
    t.uuid "payment_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payment_id"], name: "index_prescriptions_on_payment_id"
    t.index ["requested_at"], name: "index_prescriptions_on_requested_at"
    t.index ["status"], name: "index_prescriptions_on_status"
    t.index ["user_id", "created_at"], name: "index_prescriptions_on_user_id_and_created_at"
    t.index ["user_id", "status", "created_at"], name: "idx_prescriptions_user_status_created"
    t.index ["user_id", "status"], name: "index_prescriptions_on_user_id_and_status"
    t.index ["user_id"], name: "index_prescriptions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "is_patient", default: true, null: false
    t.boolean "is_doctor", default: false, null: false
    t.boolean "is_admin", default: false, null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "messages", "messages", column: "parent_message_id", on_delete: :nullify
  add_foreign_key "messages", "prescriptions"
  add_foreign_key "prescriptions", "payments"
  add_foreign_key "prescriptions", "users"
end
