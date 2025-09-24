class AddRatingToRestaurants < ActiveRecord::Migration[8.0]
  def change
    add_column :restaurants, :rating, :decimal, precision: 3, scale: 1
  end
end
