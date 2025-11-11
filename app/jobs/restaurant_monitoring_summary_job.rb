class RestaurantMonitoringSummaryJob < ApplicationJob
  queue_as :restaurants

  def perform(monitoring_started_at)
    Rails.logger.info "=== Generating Monitoring Summary ==="

    # Count checks that happened since the monitoring cycle started
    checks = RestaurantStatusCheck.where("checked_at >= ?", monitoring_started_at)

    results = {
      total_checks: checks.count,
      anomalies: checks.where(is_anomaly: true).count,
      errors: checks.where(actual_status: "error").count,
      open_count: checks.where(actual_status: "open").count,
      closed_count: checks.where(actual_status: "closed").count,
      duration: Time.current - monitoring_started_at
    }

    Rails.logger.info "Summary: #{results}"

    # Send notification if there are anomalies
    if results[:anomalies] > 0
      Rails.logger.info "Sending monitoring summary notification (#{results[:anomalies]} anomalies)"
      NotificationService.new.send_monitoring_summary(results, results[:duration])
    else
      Rails.logger.info "No anomalies detected - skipping summary notification"
    end

    results
  end
end
