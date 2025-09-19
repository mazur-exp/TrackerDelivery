class UpdateRestaurantCuisineFields < ActiveRecord::Migration[8.0]
  def change
    remove_column :restaurants, :cuisine_type, :string

    add_column :restaurants, :cuisine_primary, :string
    add_column :restaurants, :cuisine_secondary, :string
    add_column :restaurants, :cuisine_tertiary, :string
  end
end
