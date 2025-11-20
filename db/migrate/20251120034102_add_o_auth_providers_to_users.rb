class AddOAuthProvidersToUsers < ActiveRecord::Migration[8.0]
  def change
    # Google OAuth fields
    add_column :users, :google_id, :string
    add_column :users, :google_email, :string
    add_column :users, :google_picture, :string

    # Apple OAuth fields
    add_column :users, :apple_id, :string

    # Facebook OAuth fields
    add_column :users, :facebook_id, :string

    # Unique indexes for OAuth provider IDs
    add_index :users, :google_id, unique: true
    add_index :users, :apple_id, unique: true
    add_index :users, :facebook_id, unique: true
  end
end
