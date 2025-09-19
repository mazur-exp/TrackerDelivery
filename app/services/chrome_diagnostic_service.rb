class ChromeDiagnosticService
  def self.diagnose
    Rails.logger.info "=== Chrome/ChromeDriver Diagnostic Report ==="
    
    # System architecture
    arch = `uname -m`.strip rescue "unknown"
    Rails.logger.info "System Architecture: #{arch}"
    
    # Environment variables
    Rails.logger.info "Environment Variables:"
    Rails.logger.info "  CHROME_BIN: #{ENV['CHROME_BIN'] || 'not set'}"
    Rails.logger.info "  CHROMEDRIVER_PATH: #{ENV['CHROMEDRIVER_PATH'] || 'not set'}"
    
    # Search for Chrome binaries
    Rails.logger.info "Chrome Binary Search:"
    chrome_candidates = [
      "/usr/bin/google-chrome-stable",
      "/usr/bin/google-chrome", 
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser"
    ]
    
    chrome_candidates.each do |path|
      if File.exist?(path)
        executable = File.executable?(path)
        version = get_version(path) if executable
        Rails.logger.info "  #{path}: exists=true, executable=#{executable}, version=#{version || 'failed'}"
      else
        Rails.logger.info "  #{path}: exists=false"
      end
    end
    
    # Search for ChromeDriver binaries
    Rails.logger.info "ChromeDriver Binary Search:"
    chromedriver_candidates = [
      "/usr/local/bin/chromedriver",
      "/usr/bin/chromedriver",
      "/usr/lib/chromium/chromedriver",
      "/usr/lib/chromium-browser/chromedriver"
    ]
    
    chromedriver_candidates.each do |path|
      if File.exist?(path)
        executable = File.executable?(path)
        version = get_chromedriver_version(path) if executable
        Rails.logger.info "  #{path}: exists=true, executable=#{executable}, version=#{version || 'failed'}"
      else
        Rails.logger.info "  #{path}: exists=false"
      end
    end
    
    # Search filesystem for Chrome/ChromeDriver
    Rails.logger.info "Filesystem Search Results:"
    chrome_search = `find /usr -name "chrome*" -o -name "chromium*" -type f 2>/dev/null | grep -E "(chrome|chromium)$"`.strip
    chromedriver_search = `find /usr -name "chromedriver" -type f 2>/dev/null`.strip
    
    Rails.logger.info "  Chrome binaries found: #{chrome_search.split("\n").join(', ')}"
    Rails.logger.info "  ChromeDriver binaries found: #{chromedriver_search.split("\n").join(', ')}"
    
    # Package information (if available)
    Rails.logger.info "Package Information:"
    chrome_package = `dpkg -l | grep -E "(chrome|chromium)" 2>/dev/null`.strip
    Rails.logger.info "  Installed packages: #{chrome_package.present? ? chrome_package : 'none found'}"
    
    # Selenium version
    begin
      require 'selenium-webdriver'
      Rails.logger.info "Selenium WebDriver Version: #{Selenium::WebDriver::VERSION}"
    rescue => e
      Rails.logger.error "Selenium WebDriver: #{e.message}"
    end
    
    Rails.logger.info "=== End Diagnostic Report ==="
  end
  
  def self.test_webdriver_creation
    Rails.logger.info "=== Testing WebDriver Creation ==="
    
    begin
      # Try to create a simple WebDriver instance
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      
      # Try with environment ChromeDriver path
      if ENV['CHROMEDRIVER_PATH'] && File.exist?(ENV['CHROMEDRIVER_PATH'])
        Rails.logger.info "Attempting with CHROMEDRIVER_PATH: #{ENV['CHROMEDRIVER_PATH']}"
        service = Selenium::WebDriver::Service.chrome(path: ENV['CHROMEDRIVER_PATH'])
        driver = Selenium::WebDriver.for(:chrome, service: service, options: options)
        driver.quit
        Rails.logger.info "SUCCESS: WebDriver creation successful with explicit path"
        return true
      else
        Rails.logger.info "Attempting with default ChromeDriver detection"
        driver = Selenium::WebDriver.for(:chrome, options: options)
        driver.quit
        Rails.logger.info "SUCCESS: WebDriver creation successful with default detection"
        return true
      end
      
    rescue => e
      Rails.logger.error "FAILED: WebDriver creation failed: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.first(3).join("\n")}"
      return false
    end
  end
  
  private
  
  def self.get_version(binary_path)
    `#{binary_path} --version 2>/dev/null`.strip
  rescue
    nil
  end
  
  def self.get_chromedriver_version(binary_path)
    `#{binary_path} --version 2>/dev/null`.strip
  rescue
    nil
  end
end