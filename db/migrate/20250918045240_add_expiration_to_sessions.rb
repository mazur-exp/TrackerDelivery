class AddExpirationToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :expires_at, :datetime
    add_column :sessions, :max_lifetime_expires_at, :datetime
  end
end
