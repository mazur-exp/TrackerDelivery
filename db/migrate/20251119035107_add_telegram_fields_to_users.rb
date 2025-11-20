class AddTelegramFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    # Add Telegram authentication fields
    add_column :users, :telegram_id, :bigint
    add_column :users, :telegram_username, :string
    add_column :users, :telegram_first_name, :string
    add_column :users, :telegram_last_name, :string
    add_column :users, :telegram_photo_url, :string
    add_column :users, :telegram_auth_date, :datetime

    # Add unique index on telegram_id for fast lookups and uniqueness enforcement
    add_index :users, :telegram_id, unique: true

    # Make email_address and password_digest nullable (optional for Telegram users)
    change_column_null :users, :email_address, true
    change_column_null :users, :password_digest, true
  end
end
