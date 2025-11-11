class RestaurantMonitoringWorkerJob < ApplicationJob
  queue_as :restaurants

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(restaurant_id)
    restaurant = Restaurant.find(restaurant_id)
    Rails.logger.info "Worker started for restaurant: #{restaurant.name} (ID: #{restaurant_id})"

    check_restaurant_status(restaurant)

    Rails.logger.info "Worker completed for restaurant: #{restaurant.name}"
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Restaurant with ID #{restaurant_id} not found"
  rescue => e
    Rails.logger.error "Worker error for restaurant #{restaurant_id}: #{e.message}"

    # Still record the error status if we have the restaurant
    begin
      restaurant = Restaurant.find(restaurant_id)
      record_status_check(restaurant, nil, "error", e.message)
    rescue
      # If we can't even find the restaurant, just log it
    end

    raise # Re-raise to trigger retry logic
  end

  private

  def check_restaurant_status(restaurant)
    # Use database-level advisory lock to prevent duplicate processing
    lock_key = "restaurant_monitoring_#{restaurant.id}"

    # For SQLite, use simpler approach with timestamp check
    if Restaurant.connection.adapter_name.include?("SQLite")
      # Check if restaurant was processed in last 4 minutes (buffer before 5min schedule)
      last_check = restaurant.restaurant_status_checks.order(checked_at: :desc).first
      if last_check && last_check.checked_at > 4.minutes.ago
        Rails.logger.info "Skipping #{restaurant.name} - recently processed at #{last_check.checked_at}"
        return nil
      end
    else
      # Try to acquire lock for PostgreSQL
      result = Restaurant.connection.execute(
        "SELECT pg_try_advisory_lock(hashtext('#{lock_key}')) as acquired"
      ).first rescue nil

      if !result || result["acquired"] != true
        Rails.logger.info "Skipping #{restaurant.name} - being processed by another worker"
        return nil
      end
    end

    begin
      Rails.logger.info "Checking restaurant: #{restaurant.name} (#{restaurant.platform})"

      # Get current expected status
      expected_status = restaurant.expected_status_at(Time.current)

      # Get full restaurant data from parser (including rating)
      full_data = get_full_restaurant_data(restaurant)

      # Extract status data
      actual_status_data = extract_status_from_full_data(full_data)
      actual_status = determine_actual_status(actual_status_data)

      # Update restaurant with new rating and review count if available
      update_restaurant_data(restaurant, full_data)

      # Check for anomaly
      is_anomaly = is_status_anomaly?(expected_status, actual_status)

      # Record the check
      status_check = record_status_check(
        restaurant,
        actual_status_data,
        actual_status,
        expected_status,
        is_anomaly
      )

      # Send notification if anomaly detected
      if is_anomaly
        Rails.logger.warn "ANOMALY DETECTED for #{restaurant.name}: expected #{expected_status}, got #{actual_status}"
        Rails.logger.info "Sending anomaly notification for #{restaurant.name}"
        NotificationService.new.send_restaurant_anomaly_alert(restaurant, status_check)
      end

      status_check
    ensure
      # Release advisory lock for PostgreSQL
      unless Restaurant.connection.adapter_name.include?("SQLite")
        Restaurant.connection.execute(
          "SELECT pg_advisory_unlock(hashtext('#{lock_key}'))"
        ) rescue nil
      end
    end
  end

  def get_full_restaurant_data(restaurant)
    Rails.logger.info "Getting full restaurant data for monitoring"

    case restaurant.platform
    when "grab"
      GrabParserService.new.parse(restaurant.platform_url)
    when "gojek"
      GojekParserService.new.parse(restaurant.platform_url)
    else
      Rails.logger.error "Unknown platform: #{restaurant.platform}"
      nil
    end
  rescue => e
    Rails.logger.error "Error getting full restaurant data: #{e.message}"
    nil
  end

  def extract_status_from_full_data(full_data)
    return { is_open: nil, status_text: "error", error: "No data received" } unless full_data

    if full_data[:status]
      full_data[:status]
    else
      # Fallback to assuming open if no status data but got other data
      { is_open: true, status_text: "open", error: nil }
    end
  end

  def update_restaurant_data(restaurant, full_data)
    return unless full_data

    updates = {}

    # Update rating if present and different
    if full_data[:rating].present? && full_data[:rating] != restaurant.rating
      updates[:rating] = full_data[:rating]
      Rails.logger.info "Updating rating from #{restaurant.rating} to #{full_data[:rating]}"
    end

    # Save updates if any
    if updates.any?
      restaurant.update!(updates)
      Rails.logger.info "Restaurant #{restaurant.name} updated with new data"
    end
  rescue => e
    Rails.logger.error "Error updating restaurant data: #{e.message}"
  end

  def determine_actual_status(status_data)
    return "error" if status_data.nil? || status_data[:error]
    return "unknown" if status_data[:is_open].nil?

    status_data[:is_open] ? "open" : "closed"
  end

  def is_status_anomaly?(expected, actual)
    # Only consider it an anomaly if there's a clear mismatch
    return false if expected == "unknown" || actual == "unknown"
    return false if actual == "error"  # Errors are tracked but not considered schedule anomalies

    # Main anomaly: restaurant should be open but is closed
    if expected == "open" && actual == "closed"
      return true
    end

    # Secondary anomaly: restaurant is open but should be closed (less critical)
    if expected == "closed" && actual == "open"
      return true
    end

    false
  end

  def record_status_check(restaurant, status_data, actual_status, expected_status = nil, is_anomaly = false)
    expected_status ||= restaurant.expected_status_at(Time.current)

    RestaurantStatusCheck.create!(
      restaurant: restaurant,
      checked_at: Time.current,
      actual_status: actual_status,
      expected_status: expected_status,
      is_anomaly: is_anomaly,
      parser_response: status_data.to_json
    )
  end
end
