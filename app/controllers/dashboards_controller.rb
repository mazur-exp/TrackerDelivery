class DashboardsController < ApplicationController
  layout false

  def show
    if current_user
      @restaurants = current_user.restaurants
        .includes(:notification_contacts, :working_hours, :menu_items)
        .ordered_by_status
      @total_restaurants = @restaurants.count
      @average_rating = calculate_average_rating(@restaurants)

      # Precompute status data for live timers
      @status_data = build_status_data(@restaurants)

      # Out-of-stock items across all restaurants
      @out_of_stock_items = MenuItem.joins(:restaurant)
        .where(restaurants: { user_id: current_user.id, is_active: true })
        .where(current_status: 0)
        .includes(:restaurant)
        .order(:status_changed_at)
    else
      @restaurants = []
      @total_restaurants = 0
      @average_rating = 0
      @status_data = {}
      @out_of_stock_items = []
    end
  end

  # JSON endpoint for live status updates (AJAX polling)
  def status_data
    return render(json: { error: "unauthorized" }, status: 401) unless current_user

    restaurants = current_user.restaurants.active.includes(:menu_items)
    data = build_status_data(restaurants)
    render json: data
  end

  # JSON endpoint for timeline data
  def timeline_data
    return render(json: { error: "unauthorized" }, status: 401) unless current_user

    restaurant = current_user.restaurants.find(params[:restaurant_id])
    date = params[:date]&.to_date || Date.current

    # Get checks for the date in Bali timezone
    bali_tz = ActiveSupport::TimeZone["Asia/Makassar"]
    day_start = bali_tz.local(date.year, date.month, date.day).utc
    day_end = day_start + 1.day

    checks = restaurant.restaurant_status_checks
      .where(checked_at: day_start..day_end)
      .order(checked_at: :asc)

    segments = build_timeline_segments(checks, day_start, day_end)

    render json: {
      restaurant_id: restaurant.id,
      date: date.iso8601,
      segments: segments
    }
  end

  def onboarding
    if current_user
      @existing_whatsapp_contacts = current_user.all_whatsapp_contacts
      @existing_telegram_contacts = current_user.all_telegram_contacts
      @existing_email_contacts = current_user.all_email_contacts
      @user_has_restaurants = current_user.has_restaurants?
    else
      @existing_whatsapp_contacts = []
      @existing_telegram_contacts = []
      @existing_email_contacts = []
      @user_has_restaurants = false
    end
  end

  private

  def build_status_data(restaurants)
    bali_tz = ActiveSupport::TimeZone["Asia/Makassar"]
    today_start = bali_tz.now.beginning_of_day.utc

    data = {}
    restaurants.each do |r|
      checks_today = r.restaurant_status_checks
        .where("checked_at >= ?", today_start)
        .order(checked_at: :desc)

      last_check = checks_today.first
      next unless last_check

      # Find when current status started
      current_status = last_check.actual_status
      status_since = last_check.checked_at
      checks_today.each do |c|
        break if c.actual_status != current_status
        status_since = c.checked_at
      end

      # Calculate today's uptime
      total_checks = checks_today.count
      open_checks = checks_today.where(actual_status: "open").count
      closed_checks = checks_today.where(actual_status: "closed").count
      error_checks = checks_today.where(actual_status: "error").count

      # Each check = ~5 minutes
      open_minutes = open_checks * 5
      closed_minutes = closed_checks * 5

      # Uptime % (only counting non-error checks)
      valid_checks = open_checks + closed_checks
      uptime_pct = valid_checks > 0 ? (open_checks.to_f / valid_checks * 100).round(1) : nil

      # Menu items summary
      total_items = r.menu_items.count
      oos_items = r.menu_items.out_of_stock.count

      data[r.id] = {
        restaurant_id: r.id,
        current_status: current_status,
        status_since: status_since.iso8601,
        open_minutes: open_minutes,
        closed_minutes: closed_minutes,
        uptime_pct: uptime_pct,
        total_checks: total_checks,
        error_checks: error_checks,
        total_menu_items: total_items,
        oos_menu_items: oos_items,
        last_checked_at: last_check.checked_at.iso8601
      }
    end
    data
  end

  def build_timeline_segments(checks, day_start, day_end)
    return [] if checks.empty?

    segments = []
    current_status = nil
    segment_start = nil

    checks.each do |check|
      if check.actual_status != current_status
        # Close previous segment
        if current_status && segment_start
          segments << {
            status: current_status,
            start: segment_start.iso8601,
            end: check.checked_at.iso8601,
            start_pct: ((segment_start - day_start) / (day_end - day_start) * 100).round(2),
            end_pct: ((check.checked_at - day_start) / (day_end - day_start) * 100).round(2)
          }
        end
        current_status = check.actual_status
        segment_start = check.checked_at
      end
    end

    # Close last segment (extends to now or end of day)
    if current_status && segment_start
      segment_end = [Time.current, day_end].min
      segments << {
        status: current_status,
        start: segment_start.iso8601,
        end: segment_end.iso8601,
        start_pct: ((segment_start - day_start) / (day_end - day_start) * 100).round(2),
        end_pct: ((segment_end - day_start) / (day_end - day_start) * 100).round(2)
      }
    end

    segments
  end

  def calculate_average_rating(restaurants)
    return 0 if restaurants.empty?
    ratings = restaurants.map(&:rating).compact.reject { |r| r == "NEW" || r.blank? }
    return 0 if ratings.empty?
    numeric_ratings = ratings.map(&:to_f).reject(&:zero?)
    return 0 if numeric_ratings.empty?
    (numeric_ratings.sum / numeric_ratings.size).round(1)
  end
end
