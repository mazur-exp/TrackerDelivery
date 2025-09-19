class ChangeNotificationContactsToRestaurant < ActiveRecord::Migration[8.0]
  def change
    # Remove existing indexes and foreign key
    remove_index :notification_contacts, name: "index_notification_contacts_on_user_type_primary"
    remove_index :notification_contacts, name: "index_notification_contacts_on_user_id_and_contact_type"
    remove_index :notification_contacts, name: "index_notification_contacts_on_user_id_and_is_primary"
    remove_index :notification_contacts, name: "index_notification_contacts_on_user_id"
    remove_foreign_key :notification_contacts, :users

    # Rename column from user_id to restaurant_id
    rename_column :notification_contacts, :user_id, :restaurant_id

    # Add new indexes and foreign key
    add_index :notification_contacts, :restaurant_id
    add_index :notification_contacts, [ :restaurant_id, :contact_type ]
    add_index :notification_contacts, [ :restaurant_id, :contact_type, :is_primary ], name: "index_notification_contacts_on_restaurant_type_primary"
    add_index :notification_contacts, [ :restaurant_id, :is_primary ], name: "index_notification_contacts_on_restaurant_id_and_is_primary"
    add_foreign_key :notification_contacts, :restaurants
  end
end
