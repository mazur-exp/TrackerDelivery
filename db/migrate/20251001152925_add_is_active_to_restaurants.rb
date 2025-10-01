class AddIsActiveToRestaurants < ActiveRecord::Migration[8.0]
  def change
    add_column :restaurants, :is_active, :boolean, default: true, null: false
    add_index :restaurants, :is_active
  end
end
