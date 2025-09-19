class CreateCuisineTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :cuisine_translations do |t|
      t.string :indonesian, null: false
      t.string :english, null: false

      t.timestamps
    end
    
    add_index :cuisine_translations, :indonesian, unique: true
  end
end
