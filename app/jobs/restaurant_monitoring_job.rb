class RestaurantMonitoringJob < ApplicationJob
  queue_as :restaurants

  def perform
    Rails.logger.info "=== Restaurant Monitoring Coordinator Started ==="
    start_time = Time.current

    restaurants = Restaurant.active.includes(:working_hours, :notification_contacts)
    Rails.logger.info "Enqueuing monitoring jobs for #{restaurants.count} active restaurants"

    # Track job metadata
    jobs_enqueued = 0

    # Enqueue individual worker jobs for each restaurant
    restaurants.find_each do |restaurant|
      # Add staggered delay to avoid overwhelming the system
      # Each restaurant gets checked with a small delay between them
      RestaurantMonitoringWorkerJob.perform_later(restaurant.id)
      jobs_enqueued += 1

      Rails.logger.info "Enqueued worker job for #{restaurant.name} (ID: #{restaurant.id}) with #{jobs_enqueued * 2}s delay"
    end

    duration = Time.current - start_time
    Rails.logger.info "=== Coordinator completed in #{duration.round(2)}s ==="
    Rails.logger.info "Enqueued #{jobs_enqueued} worker jobs"

    # Schedule a summary job to run after all workers should be done
    # Estimate: 2 seconds per restaurant + 30 seconds buffer for processing
    summary_delay = (jobs_enqueued * 2) + 30
    RestaurantMonitoringSummaryJob.set(wait: summary_delay.seconds).perform_later(start_time)

    { total: restaurants.count, jobs_enqueued: jobs_enqueued }
  end
end
