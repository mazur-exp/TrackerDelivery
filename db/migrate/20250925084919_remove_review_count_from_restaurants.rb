class RemoveReviewCountFromRestaurants < ActiveRecord::Migration[8.0]
  def change
    remove_column :restaurants, :review_count, :integer
  end
end
