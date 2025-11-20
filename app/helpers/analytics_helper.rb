class AnalyticsHelper
  # Revenue loss assumption: Rp 50,000 per hour when restaurant should be open but is closed
  REVENUE_LOSS_PER_HOUR = 50_000

  def initialize(restaurant)
    @restaurant = restaurant
  end

  # Fetch status checks for a given period
  def fetch_checks_for_period(period)
    time_range = case period
    when "24h"
      24.hours.ago..Time.current
    when "7d"
      7.days.ago..Time.current
    when "30d"
      30.days.ago..Time.current
    else
      24.hours.ago..Time.current
    end

    @restaurant.restaurant_status_checks
               .where(checked_at: time_range)
               .order(checked_at: :asc)
  end

  # Calculate uptime percentage
  def calculate_uptime(checks)
    return 0 if checks.empty?

    # Count checks where restaurant was expected to be open
    expected_open_checks = checks.select { |c| c.expected_status == "open" }
    return 100 if expected_open_checks.empty?

    # Count how many of those were actually open
    actually_open_count = expected_open_checks.count { |c| c.actual_status == "open" }

    ((actually_open_count.to_f / expected_open_checks.count) * 100).round(2)
  end

  # Calculate revenue loss from anomalies
  def calculate_revenue_loss(checks)
    # Find anomalies where restaurant should be open but was closed
    critical_anomalies = checks.select do |c|
      c.is_anomaly? && c.expected_status == "open" && c.actual_status == "closed"
    end

    return 0 if critical_anomalies.empty?

    # Group consecutive anomalies to count continuous downtime periods
    downtime_periods = group_consecutive_anomalies(critical_anomalies)

    # Calculate revenue loss: each period costs REVENUE_LOSS_PER_HOUR
    # Checks are every 5 minutes, so 12 checks = 1 hour
    total_anomaly_checks = critical_anomalies.count
    hours_of_downtime = (total_anomaly_checks / 12.0).ceil

    (hours_of_downtime * REVENUE_LOSS_PER_HOUR).to_i
  end

  # Aggregate checks by time period (hourly for 24h, daily for 7d/30d)
  def aggregate_checks_by_time(checks, period)
    return [] if checks.empty?

    interval = period == "24h" ? :hour : :day

    if interval == :hour
      aggregate_checks_by_hour(checks)
    else
      aggregate_checks_by_day(checks)
    end
  end

  # Aggregate checks by hour
  def aggregate_checks_by_hour(checks)
    grouped = checks.group_by { |c| c.checked_at.beginning_of_hour }

    grouped.map do |hour, hour_checks|
      online_count = hour_checks.count { |c| c.actual_status == "open" }
      closed_count = hour_checks.count { |c| c.actual_status == "closed" }
      unknown_count = hour_checks.count { |c| c.actual_status == "unknown" }
      anomaly_count = hour_checks.count(&:is_anomaly?)

      {
        timestamp: hour.to_i * 1000, # JavaScript timestamp
        label: hour.strftime("%H:%M"),
        online: online_count,
        closed: closed_count,
        unknown: unknown_count,
        anomalies: anomaly_count,
        total: hour_checks.count
      }
    end.sort_by { |h| h[:timestamp] }
  end

  # Aggregate checks by day
  def aggregate_checks_by_day(checks)
    grouped = checks.group_by { |c| c.checked_at.beginning_of_day }

    grouped.map do |day, day_checks|
      online_count = day_checks.count { |c| c.actual_status == "open" }
      closed_count = day_checks.count { |c| c.actual_status == "closed" }
      unknown_count = day_checks.count { |c| c.actual_status == "unknown" }
      anomaly_count = day_checks.count(&:is_anomaly?)

      {
        timestamp: day.to_i * 1000,
        label: day.strftime("%b %d"),
        online: online_count,
        closed: closed_count,
        unknown: unknown_count,
        anomalies: anomaly_count,
        total: day_checks.count
      }
    end.sort_by { |h| h[:timestamp] }
  end

  # Platform comparison data (for future multi-platform support)
  def platform_comparison_data(period)
    checks = fetch_checks_for_period(period)

    {
      platform: @restaurant.platform,
      total_checks: checks.count,
      uptime: calculate_uptime(checks),
      anomalies: checks.count(&:is_anomaly?),
      status: latest_status(checks)
    }
  end

  # Get recent anomalies for display
  def recent_anomalies(checks, limit: 10)
    anomalies = checks.select(&:is_anomaly?).last(limit)

    anomalies.map do |check|
      {
        id: check.id,
        checked_at: check.checked_at,
        formatted_time: time_ago_in_words(check.checked_at),
        expected_status: check.expected_status,
        actual_status: check.actual_status,
        severity: check.anomaly_severity.to_s,
        severity_badge: severity_badge_class(check.anomaly_severity)
      }
    end.reverse
  end

  private

  # Group consecutive anomalies to identify continuous downtime periods
  def group_consecutive_anomalies(anomalies)
    return [] if anomalies.empty?

    periods = []
    current_period = [ anomalies.first ]

    anomalies.each_cons(2) do |prev, curr|
      # If checks are within 10 minutes of each other, consider them consecutive
      if (curr.checked_at - prev.checked_at) <= 10.minutes
        current_period << curr
      else
        periods << current_period
        current_period = [ curr ]
      end
    end

    periods << current_period
    periods
  end

  # Get latest status from checks
  def latest_status(checks)
    return "unknown" if checks.empty?
    checks.last.actual_status
  end

  # Helper to format time ago
  def time_ago_in_words(time)
    seconds_diff = (Time.current - time).to_i

    case seconds_diff
    when 0..59
      "#{seconds_diff}s ago"
    when 60..3599
      "#{(seconds_diff / 60)}m ago"
    when 3600..86399
      "#{(seconds_diff / 3600)}h ago"
    else
      "#{(seconds_diff / 86400)}d ago"
    end
  end

  # Severity badge CSS classes
  def severity_badge_class(severity)
    case severity
    when :high
      "bg-red-500 text-white"
    when :medium
      "bg-yellow-500 text-white"
    when :low
      "bg-blue-500 text-white"
    else
      "bg-gray-500 text-white"
    end
  end
end
