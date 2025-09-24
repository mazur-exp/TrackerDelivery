class ChangeRatingToStringInRestaurants < ActiveRecord::Migration[8.0]
  def up
    # Convert existing decimal ratings to strings, and set 0.0/nil to "NEW"
    execute <<~SQL
      UPDATE restaurants 
      SET rating = CASE 
        WHEN rating IS NULL OR rating = 0.0 THEN 'NEW'
        ELSE CAST(rating AS TEXT)
      END
    SQL
    
    # Change column type to string
    change_column :restaurants, :rating, :string
  end

  def down
    # Convert back to decimal, treating "NEW" as NULL
    execute <<~SQL
      UPDATE restaurants 
      SET rating = CASE 
        WHEN rating = 'NEW' THEN NULL
        ELSE CAST(rating AS DECIMAL(3,1))
      END
    SQL
    
    # Change column type back to decimal
    change_column :restaurants, :rating, :decimal, precision: 3, scale: 1
  end
end
