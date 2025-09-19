# Chrome/ChromeDriver setup validation for production
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Run diagnostic in background thread to not block startup
    Thread.new do
      begin
        sleep(2) # Give Rails time to fully initialize
        Rails.logger.info "=== Chrome Setup Validation ==="

        # Basic environment check
        chrome_bin = ENV["CHROME_BIN"]
        chromedriver_path = ENV["CHROMEDRIVER_PATH"]

        Rails.logger.info "CHROME_BIN: #{chrome_bin || 'not set'}"
        Rails.logger.info "CHROMEDRIVER_PATH: #{chromedriver_path || 'not set'}"

        # Run diagnostic service
        ChromeDiagnosticService.diagnose

        # Test WebDriver creation
        if ChromeDiagnosticService.test_webdriver_creation
          Rails.logger.info "✓ Chrome/ChromeDriver setup validation successful"
        else
          Rails.logger.error "✗ Chrome/ChromeDriver setup validation failed"
        end

      rescue => e
        Rails.logger.error "Chrome setup validation error: #{e.message}"
      end
    end
  end
end
