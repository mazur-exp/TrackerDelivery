class CreateWorkingHours < ActiveRecord::Migration[8.0]
  def change
    create_table :working_hours do |t|
      t.references :restaurant, null: false, foreign_key: true
      t.integer :day_of_week, null: false
      t.time :opens_at
      t.time :closes_at
      t.time :break_start
      t.time :break_end
      t.boolean :is_closed, default: false

      t.timestamps
    end

    add_index :working_hours, [ :restaurant_id, :day_of_week ], unique: true
  end
end
