# Restaurant Monitoring Auto-Start Configuration
# 
# This initializer ensures that restaurant monitoring jobs are automatically
# started when Rails application boots up, providing 24/7 monitoring without
# manual intervention after server restarts.

Rails.application.config.after_initialize do
  # Only start monitoring in production and development environments
  # Skip during tests, migrations, console operations, or asset precompilation
  unless Rails.env.test? || defined?(Rails::Console) || File.basename($0) == 'rake' || ENV['ASSETS_PRECOMPILE'] || ENV['SECRET_KEY_BASE_DUMMY']
    Rails.logger.info "🚀 Starting Restaurant Monitoring System..."
    
    # Check if monitoring jobs are already running to prevent duplication
    # In Rails 8 with Solid Queue, we can check for existing jobs
    begin
      # Count existing scheduled monitoring jobs
      existing_jobs_count = 0
      
      # Try to get job count from Solid Queue (Rails 8)
      if defined?(SolidQueue) && ActiveRecord::Base.connection.table_exists?('solid_queue_jobs')
        existing_jobs_count = SolidQueue::Job
          .where(class_name: 'RestaurantMonitoringSchedulerJob')
          .where("scheduled_at > ?", Time.current)
          .count
      end
      
      if existing_jobs_count > 0
        Rails.logger.info "📋 Restaurant monitoring already scheduled (#{existing_jobs_count} jobs found)"
      else
        # Start the monitoring scheduler job
        RestaurantMonitoringSchedulerJob.perform_later
        Rails.logger.info "✅ Restaurant monitoring scheduler started successfully"
        Rails.logger.info "🔄 Monitoring will run every 5 minutes automatically"
      end
      
    rescue => e
      # Fallback: start monitoring anyway if job count check fails
      Rails.logger.warn "⚠️  Could not check existing jobs: #{e.message}"
      Rails.logger.info "🔄 Starting monitoring anyway as fallback..."
      
      RestaurantMonitoringSchedulerJob.perform_later
      Rails.logger.info "✅ Restaurant monitoring scheduler started (fallback mode)"
    end
    
    # Log monitoring configuration
    restaurant_count = Restaurant.count rescue 0
    Rails.logger.info "📊 Monitoring configured for #{restaurant_count} restaurants"
    
  else
    Rails.logger.debug "🔇 Skipping monitoring auto-start in #{Rails.env} environment"
  end
end