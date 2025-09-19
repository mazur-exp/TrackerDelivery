class CreateNotificationContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :notification_contacts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :contact_type, null: false # 'whatsapp', 'telegram', 'email'
      t.string :contact_value, null: false # номер телефона, username, email
      t.boolean :is_primary, default: false # первый добавленный = primary
      t.integer :priority_order # порядок добавления для определения приоритета
      t.boolean :is_active, default: true # активен ли контакт

      t.timestamps
    end

    # Индексы для быстрого поиска (user_id уже создан через references)
    add_index :notification_contacts, [ :user_id, :contact_type ]
    add_index :notification_contacts, [ :user_id, :is_primary ]
    add_index :notification_contacts, [ :user_id, :contact_type, :is_primary ],
              name: 'index_notification_contacts_on_user_type_primary'
  end
end
