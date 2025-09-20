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

ActiveRecord::Schema[8.0].define(version: 2025_09_20_154400) do
  create_table "cuisine_translations", force: :cascade do |t|
    t.string "indonesian", null: false
    t.string "english", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["indonesian"], name: "index_cuisine_translations_on_indonesian", unique: true
  end

  create_table "email_domain_blacklists", force: :cascade do |t|
    t.string "domain"
    t.string "reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain"], name: "index_email_domain_blacklists_on_domain", unique: true
  end

  create_table "notification_contacts", force: :cascade do |t|
    t.integer "restaurant_id", null: false
    t.string "contact_type", null: false
    t.string "contact_value", null: false
    t.boolean "is_primary", default: false
    t.integer "priority_order"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "contact_type", "is_primary"], name: "index_notification_contacts_on_restaurant_type_primary"
    t.index ["restaurant_id", "contact_type"], name: "index_notification_contacts_on_restaurant_id_and_contact_type"
    t.index ["restaurant_id", "is_primary"], name: "index_notification_contacts_on_restaurant_id_and_is_primary"
    t.index ["restaurant_id"], name: "index_notification_contacts_on_restaurant_id"
  end

  create_table "restaurants", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address"
    t.string "phone"
    t.string "cuisine_primary"
    t.string "cuisine_secondary"
    t.string "cuisine_tertiary"
    t.string "image_url"
    t.string "platform", null: false
    t.string "platform_url", null: false
    t.text "coordinates"
    t.index ["platform"], name: "index_restaurants_on_platform"
    t.index ["user_id"], name: "index_restaurants_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "user_agent"
    t.string "ip_address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "expires_at"
    t.datetime "max_lifetime_expires_at"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address"
    t.string "password_digest"
    t.string "name"
    t.datetime "email_confirmed_at"
    t.string "email_confirmation_token"
    t.datetime "email_confirmation_sent_at"
    t.string "password_reset_token"
    t.datetime "password_reset_sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["email_confirmation_token"], name: "index_users_on_email_confirmation_token", unique: true
    t.index ["password_reset_token"], name: "index_users_on_password_reset_token", unique: true
  end

  create_table "working_hours", force: :cascade do |t|
    t.integer "restaurant_id", null: false
    t.integer "day_of_week", null: false
    t.time "opens_at"
    t.time "closes_at"
    t.time "break_start"
    t.time "break_end"
    t.boolean "is_closed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "day_of_week"], name: "index_working_hours_on_restaurant_id_and_day_of_week", unique: true
    t.index ["restaurant_id"], name: "index_working_hours_on_restaurant_id"
  end

  add_foreign_key "notification_contacts", "restaurants"
  add_foreign_key "restaurants", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "working_hours", "restaurants"
end
