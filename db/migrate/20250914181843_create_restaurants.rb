class CreateRestaurants < ActiveRecord::Migration[8.0]
  def change
    create_table :restaurants do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :gojek_url
      t.string :grab_url

      t.timestamps
    end
  end
end
