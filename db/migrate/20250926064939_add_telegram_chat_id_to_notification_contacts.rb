class AddTelegramChatIdToNotificationContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :notification_contacts, :telegram_chat_id, :string
    add_index :notification_contacts, :telegram_chat_id
  end
end
