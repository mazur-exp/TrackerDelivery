class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email_address
      t.string :password_digest
      t.string :name
      t.datetime :email_confirmed_at
      t.string :email_confirmation_token
      t.datetime :email_confirmation_sent_at
      t.string :password_reset_token
      t.datetime :password_reset_sent_at

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, :email_confirmation_token, unique: true
    add_index :users, :password_reset_token, unique: true
  end
end
