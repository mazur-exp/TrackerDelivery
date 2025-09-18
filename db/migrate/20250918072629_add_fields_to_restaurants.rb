class AddFieldsToRestaurants < ActiveRecord::Migration[8.0]
  def change
    add_column :restaurants, :address, :string
    add_column :restaurants, :phone, :string
    add_column :restaurants, :cuisine_type, :string
  end
end
