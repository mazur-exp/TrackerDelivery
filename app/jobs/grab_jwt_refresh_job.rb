class GrabJwtRefreshJob < ApplicationJob
  queue_as :default

  # Don't retry too aggressively - next scheduled run is in 4 minutes
  retry_on StandardError, wait: 30.seconds, attempts: 2

  def perform
    # Skip if JWT is still fresh
    if GrabJwtRefreshService.token_fresh?
      Rails.logger.info "[GrabJWT] Token still fresh, skipping refresh"
      return
    end

    # Ensure Xvfb is running
    ensure_xvfb_running!

    service = GrabJwtRefreshService.new
    success = service.refresh!

    if success
      Rails.logger.info "[GrabJWT] Token refreshed successfully"
    else
      Rails.logger.error "[GrabJWT] Token refresh failed"
    end
  end

  private

  def ensure_xvfb_running!
    # Check if Xvfb is already running on display :99
    xvfb_running = system("pgrep -f 'Xvfb :99' > /dev/null 2>&1")

    unless xvfb_running
      Rails.logger.info "[GrabJWT] Starting Xvfb on display :99"
      system("Xvfb :99 -screen 0 1920x1080x24 -ac &")
      sleep(1)
    end

    ENV["DISPLAY"] = ":99"
  end
end
