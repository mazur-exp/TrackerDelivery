class AddImageUrlToRestaurants < ActiveRecord::Migration[8.0]
  def change
    add_column :restaurants, :image_url, :string
  end
end
