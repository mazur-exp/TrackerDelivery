class CreateEmailDomainBlacklists < ActiveRecord::Migration[8.0]
  def change
    create_table :email_domain_blacklists do |t|
      t.string :domain
      t.string :reason

      t.timestamps
    end
    add_index :email_domain_blacklists, :domain, unique: true
  end
end
