class RestaurantMonitoringSchedulerJob < ApplicationJob
  queue_as :default

  def perform
    # Run the actual monitoring
    RestaurantMonitoringJob.perform_later

    # Schedule the next run in 5 minutes
    RestaurantMonitoringSchedulerJob.set(wait: 5.minutes).perform_later

    Rails.logger.info "Next restaurant monitoring scheduled in 5 minutes"
  end
end