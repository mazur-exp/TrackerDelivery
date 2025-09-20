class RefactorRestaurantsToSinglePlatform < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add new columns
    add_column :restaurants, :platform, :string
    add_column :restaurants, :platform_url, :string
    add_column :restaurants, :coordinates, :text # Will store JSON

    # Step 2: Add index for platform
    add_index :restaurants, :platform

    # Step 3: Migrate existing data
    execute <<-SQL
      -- First, create Grab restaurants
      INSERT INTO restaurants (
        user_id, name, platform, platform_url, address, phone, 
        cuisine_primary, cuisine_secondary, cuisine_tertiary, 
        image_url, coordinates, created_at, updated_at
      )
      SELECT 
        user_id, name, 'grab', grab_url, address, phone,
        cuisine_primary, cuisine_secondary, cuisine_tertiary,
        image_url, NULL, created_at, updated_at
      FROM restaurants 
      WHERE grab_url IS NOT NULL AND grab_url != '';
    SQL

    execute <<-SQL
      -- Then, create GoJek restaurants
      INSERT INTO restaurants (
        user_id, name, platform, platform_url, address, phone,
        cuisine_primary, cuisine_secondary, cuisine_tertiary,
        image_url, coordinates, created_at, updated_at
      )
      SELECT 
        user_id, name, 'gojek', gojek_url, address, phone,
        cuisine_primary, cuisine_secondary, cuisine_tertiary,
        image_url, NULL, created_at, updated_at
      FROM restaurants 
      WHERE gojek_url IS NOT NULL AND gojek_url != '';
    SQL

    # Step 4: Copy notification_contacts and working_hours for new restaurants
    # First, get mapping of old restaurant IDs to new restaurant IDs
    execute <<-SQL
      -- Create a temporary table to track restaurant mappings
      CREATE TEMPORARY TABLE restaurant_mapping (
        old_id INTEGER,
        new_grab_id INTEGER,
        new_gojek_id INTEGER
      );
    SQL
    
    # Get the mapping data
    execute <<-SQL
      INSERT INTO restaurant_mapping (old_id, new_grab_id, new_gojek_id)
      SELECT 
        orig.id as old_id,
        grab_rest.id as new_grab_id,
        gojek_rest.id as new_gojek_id
      FROM restaurants orig
      LEFT JOIN restaurants grab_rest ON grab_rest.user_id = orig.user_id 
        AND grab_rest.platform = 'grab' 
        AND grab_rest.platform_url = orig.grab_url
        AND grab_rest.created_at >= (SELECT MAX(created_at) FROM restaurants WHERE platform IS NULL)
      LEFT JOIN restaurants gojek_rest ON gojek_rest.user_id = orig.user_id 
        AND gojek_rest.platform = 'gojek' 
        AND gojek_rest.platform_url = orig.gojek_url
        AND gojek_rest.created_at >= (SELECT MAX(created_at) FROM restaurants WHERE platform IS NULL)
      WHERE orig.platform IS NULL;
    SQL

    # Copy notification_contacts
    execute <<-SQL
      -- Copy contacts for Grab restaurants
      INSERT INTO notification_contacts (
        restaurant_id, contact_type, contact_value, is_primary, 
        priority_order, is_active, created_at, updated_at
      )
      SELECT 
        rm.new_grab_id, nc.contact_type, nc.contact_value, nc.is_primary,
        nc.priority_order, nc.is_active, nc.created_at, nc.updated_at
      FROM notification_contacts nc
      JOIN restaurant_mapping rm ON nc.restaurant_id = rm.old_id
      WHERE rm.new_grab_id IS NOT NULL;
    SQL

    execute <<-SQL
      -- Copy contacts for GoJek restaurants  
      INSERT INTO notification_contacts (
        restaurant_id, contact_type, contact_value, is_primary,
        priority_order, is_active, created_at, updated_at
      )
      SELECT 
        rm.new_gojek_id, nc.contact_type, nc.contact_value, nc.is_primary,
        nc.priority_order, nc.is_active, nc.created_at, nc.updated_at
      FROM notification_contacts nc
      JOIN restaurant_mapping rm ON nc.restaurant_id = rm.old_id
      WHERE rm.new_gojek_id IS NOT NULL;
    SQL

    # Copy working_hours
    execute <<-SQL
      -- Copy working hours for Grab restaurants
      INSERT INTO working_hours (
        restaurant_id, day_of_week, opens_at, closes_at, break_start,
        break_end, is_closed, created_at, updated_at
      )
      SELECT 
        rm.new_grab_id, wh.day_of_week, wh.opens_at, wh.closes_at, wh.break_start,
        wh.break_end, wh.is_closed, wh.created_at, wh.updated_at
      FROM working_hours wh
      JOIN restaurant_mapping rm ON wh.restaurant_id = rm.old_id
      WHERE rm.new_grab_id IS NOT NULL;
    SQL

    execute <<-SQL
      -- Copy working hours for GoJek restaurants
      INSERT INTO working_hours (
        restaurant_id, day_of_week, opens_at, closes_at, break_start,
        break_end, is_closed, created_at, updated_at
      )
      SELECT 
        rm.new_gojek_id, wh.day_of_week, wh.opens_at, wh.closes_at, wh.break_start,
        wh.break_end, wh.is_closed, wh.created_at, wh.updated_at
      FROM working_hours wh
      JOIN restaurant_mapping rm ON wh.restaurant_id = rm.old_id
      WHERE rm.new_gojek_id IS NOT NULL;
    SQL
    
    # Step 5: Remove old restaurants that had URLs (they are now duplicated)
    # First delete related records, then the restaurants
    execute <<-SQL
      DELETE FROM notification_contacts 
      WHERE restaurant_id IN (
        SELECT id FROM restaurants 
        WHERE platform IS NULL 
        AND (grab_url IS NOT NULL OR gojek_url IS NOT NULL)
      );
    SQL

    execute <<-SQL
      DELETE FROM working_hours 
      WHERE restaurant_id IN (
        SELECT id FROM restaurants 
        WHERE platform IS NULL 
        AND (grab_url IS NOT NULL OR gojek_url IS NOT NULL)
      );
    SQL

    execute <<-SQL
      DELETE FROM restaurants 
      WHERE platform IS NULL 
      AND (grab_url IS NOT NULL OR gojek_url IS NOT NULL);
    SQL

    # Step 6: Remove old columns
    remove_column :restaurants, :grab_url
    remove_column :restaurants, :gojek_url

    # Step 7: Add validations
    change_column_null :restaurants, :platform, false
    change_column_null :restaurants, :platform_url, false
  end

  def down
    # Step 1: Add back old columns
    add_column :restaurants, :grab_url, :string
    add_column :restaurants, :gojek_url, :string

    # Step 2: Migrate data back (this is a simplified version)
    execute <<-SQL
      UPDATE restaurants 
      SET grab_url = platform_url 
      WHERE platform = 'grab';
    SQL

    execute <<-SQL
      UPDATE restaurants 
      SET gojek_url = platform_url 
      WHERE platform = 'gojek';
    SQL

    # Step 3: Remove new columns
    remove_index :restaurants, :platform
    remove_column :restaurants, :platform
    remove_column :restaurants, :platform_url
    remove_column :restaurants, :coordinates
  end
end