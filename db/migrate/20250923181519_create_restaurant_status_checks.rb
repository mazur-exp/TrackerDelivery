class CreateRestaurantStatusChecks < ActiveRecord::Migration[8.0]
  def change
    create_table :restaurant_status_checks do |t|
      t.references :restaurant, null: false, foreign_key: true
      t.datetime :checked_at, null: false
      t.string :actual_status, null: false
      t.string :expected_status, null: false
      t.boolean :is_anomaly, default: false
      t.text :parser_response

      t.timestamps
    end

    add_index :restaurant_status_checks, :restaurant_id, if_not_exists: true
    add_index :restaurant_status_checks, :checked_at, if_not_exists: true
    add_index :restaurant_status_checks, :is_anomaly, if_not_exists: true
  end
end