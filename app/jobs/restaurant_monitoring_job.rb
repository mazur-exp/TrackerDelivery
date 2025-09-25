class RestaurantMonitoringJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "=== Restaurant Monitoring Job Started ==="
    start_time = Time.current

    restaurants = Restaurant.includes(:working_hours, :notification_contacts).all
    Rails.logger.info "Monitoring #{restaurants.count} restaurants"

    results = {
      total: restaurants.count,
      checked: 0,
      anomalies: 0,
      errors: 0
    }

    restaurants.each do |restaurant|
      begin
        check_restaurant_status(restaurant)
        results[:checked] += 1

        # Add small delay between checks to avoid overloading servers
        sleep(2)

      rescue => e
        Rails.logger.error "Error checking restaurant #{restaurant.id}: #{e.message}"
        results[:errors] += 1

        # Still record the error status
        record_status_check(restaurant, nil, "error", e.message)
      end
    end

    # Count total anomalies found in this run
    recent_anomalies = RestaurantStatusCheck
      .where("checked_at > ?", start_time)
      .where(is_anomaly: true)
      .count
    results[:anomalies] = recent_anomalies

    duration = Time.current - start_time
    Rails.logger.info "=== Restaurant Monitoring Completed in #{duration.round(2)}s ==="
    Rails.logger.info "Results: #{results}"

    # Send summary notification if there are anomalies
    if recent_anomalies > 0
      NotificationService.new.send_monitoring_summary(results, duration)
    end

    results
  end

  private

  def check_restaurant_status(restaurant)
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
      NotificationService.new.send_restaurant_anomaly_alert(restaurant, status_check)
    end

    status_check
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

  def get_actual_status(restaurant)
    case restaurant.platform
    when "grab"
      GrabParserService.new.check_status_only(restaurant.platform_url)
    when "gojek"
      GojekParserService.new.check_status_only(restaurant.platform_url)
    else
      { is_open: nil, status_text: "unknown_platform", error: "Unknown platform: #{restaurant.platform}" }
    end
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