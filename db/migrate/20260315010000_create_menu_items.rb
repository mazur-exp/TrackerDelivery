class CreateMenuItems < ActiveRecord::Migration[8.0]
  def change
    create_table :menu_items do |t|
      t.references :restaurant, null: false, foreign_key: true
      t.string :platform_item_id, null: false
      t.string :name, null: false
      t.string :category_name
      t.integer :current_status, default: 1 # 1=available, 0=out_of_stock
      t.integer :price_cents
      t.string :image_url
      t.datetime :status_changed_at
      t.datetime :last_checked_at
      t.timestamps
    end

    add_index :menu_items, [:restaurant_id, :platform_item_id], unique: true
    add_index :menu_items, [:restaurant_id, :current_status]
  end
end
