require "selenium-webdriver"
require "json"
require "base64"
require "fileutils"

class GrabJwtRefreshService
  COOKIES_FILE = "grab_cookies.json"
  TEST_RESTAURANT_URL = "https://food.grab.com/id/en/restaurant/online-delivery/6-C65ZV62KVNEDPE"
  API_URL_PATTERN = "portal.grab.com/foodweb/guest/v2/merchants"

  # Bright Data proxies
  PROXY_HOST = "brd.superproxy.io"
  PROXY_PORT = 33335
  # Two zones to rotate between
  PROXY_ZONES = [
    { user: "brd-customer-hl_4f9d9889-zone-grab-country-id", pass: "s0w6sg9qk1gj" },
    { user: "brd-customer-hl_4f9d9889-zone-datacenter_proxy1", pass: "7ow124bbuyid" }
  ].freeze

  STEALTH_SCRIPT = <<~JS
    Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
    window.chrome = { runtime: {} };
    Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3, 4, 5] });
    Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
  JS

  def refresh!
    Rails.logger.info "[GrabJWT] Starting JWT refresh..."

    # Try up to 3 times with different proxy sessions (different IPs)
    3.times do |attempt|
      driver = nil
      begin
        Rails.logger.info "[GrabJWT] Attempt #{attempt + 1}/3..."
        driver = create_driver_with_proxy
        inject_stealth(driver)
        result = navigate_and_capture(driver)
        return true if result

        Rails.logger.warn "[GrabJWT] Attempt #{attempt + 1} failed, trying new proxy IP..."
      rescue => e
        Rails.logger.error "[GrabJWT] Attempt #{attempt + 1} error: #{e.class} - #{e.message}"
      ensure
        cleanup(driver)
      end
    end

    Rails.logger.error "[GrabJWT] All 3 attempts failed"
    false
  end

  def self.token_fresh?
    file_path = Rails.root.join("storage", COOKIES_FILE)
    file_path = Rails.root.join(COOKIES_FILE) unless File.exist?(file_path)
    return false unless File.exist?(file_path)

    data = JSON.parse(File.read(file_path))
    return false unless data["jwt_token"].present?

    timestamp = Time.parse(data["timestamp"]) rescue nil
    return false unless timestamp

    (Time.current - timestamp) < 8.minutes
  rescue
    false
  end

  private

  def create_driver_with_proxy
    # Rotate between proxy zones + random session for fresh IP
    zone = PROXY_ZONES.sample
    session_id = "jwt#{SecureRandom.hex(4)}"
    proxy_user = "#{zone[:user]}-session-#{session_id}"
    proxy_pass = zone[:pass]
    ext_path = build_proxy_extension(proxy_user, proxy_pass)

    options = Selenium::WebDriver::Chrome::Options.new
    # NO --headless: extensions don't work in headless mode
    # Use Xvfb virtual display instead (DISPLAY=:99)
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--window-size=1920,1080")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_argument("--no-first-run")
    options.add_argument("--disable-default-apps")
    options.add_argument("--ignore-certificate-errors")
    options.add_argument("--lang=en-US,en;q=0.9")

    # Load proxy auth extension
    options.add_argument("--load-extension=#{ext_path}")

    @user_data_dir = "/tmp/chrome_jwt_#{Process.pid}_#{Time.now.to_i}"
    options.add_argument("--user-data-dir=#{@user_data_dir}")

    debug_port = 9350 + rand(50)
    options.add_argument("--remote-debugging-port=#{debug_port}")

    options.add_argument("--user-agent=Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36")
    options.add_option("goog:loggingPrefs", { "performance" => "ALL" })

    chrome_bin = ENV["CHROME_BIN"] || "/usr/bin/chromium"
    options.binary = chrome_bin if File.exist?(chrome_bin)

    chromedriver = ENV["CHROMEDRIVER_PATH"] || "/usr/local/bin/chromedriver"
    service = Selenium::WebDriver::Service.chrome(path: chromedriver)

    Rails.logger.info "[GrabJWT] Chrome with Bright Data proxy (session: #{session_id})"
    Selenium::WebDriver.for(:chrome, service: service, options: options)
  end

  def build_proxy_extension(proxy_user, proxy_pass)
    ext_dir = "/tmp/proxy_ext_#{Process.pid}"
    FileUtils.rm_rf(ext_dir)
    FileUtils.mkdir_p(ext_dir)

    manifest = {
      version: "1.0.0",
      manifest_version: 2,
      name: "Proxy Auth",
      permissions: ["proxy", "tabs", "unlimitedStorage", "storage", "<all_urls>", "webRequest", "webRequestBlocking"],
      background: { scripts: ["background.js"] }
    }

    background_js = <<~JS
      var config = {
        mode: "fixed_servers",
        rules: {
          singleProxy: { scheme: "http", host: "#{PROXY_HOST}", port: #{PROXY_PORT} },
          bypassList: []
        }
      };
      chrome.proxy.settings.set({value: config, scope: "regular"}, function() {});
      chrome.webRequest.onAuthRequired.addListener(
        function(details) {
          return { authCredentials: { username: "#{proxy_user}", password: "#{proxy_pass}" } };
        },
        {urls: ["<all_urls>"]},
        ["blocking"]
      );
    JS

    File.write(File.join(ext_dir, "manifest.json"), JSON.generate(manifest))
    File.write(File.join(ext_dir, "background.js"), background_js)

    @ext_dir = ext_dir
    ext_dir
  end

  def inject_stealth(driver)
    driver.execute_cdp("Page.addScriptToEvaluateOnNewDocument", source: STEALTH_SCRIPT)
    driver.execute_cdp("Emulation.setGeolocationOverride",
      latitude: -8.6705, longitude: 115.2126, accuracy: 100)
  rescue => e
    Rails.logger.warn "[GrabJWT] Stealth: #{e.message}"
  end

  def navigate_and_capture(driver)
    # Step 1: Homepage to pass WAF
    Rails.logger.info "[GrabJWT] Step 1: Homepage (via proxy)..."
    driver.navigate.to("https://food.grab.com/")
    sleep(10)
    Rails.logger.info "[GrabJWT] Homepage: #{driver.title}"

    # Flush logs
    driver.logs.get(:performance) rescue nil

    # Step 2: Restaurant page
    Rails.logger.info "[GrabJWT] Step 2: Restaurant page..."
    driver.navigate.to(TEST_RESTAURANT_URL)
    sleep(15)

    page_title = driver.title
    Rails.logger.info "[GrabJWT] Restaurant: #{page_title}"

    if page_title.blank? || page_title == "food.grab.com"
      sleep(10)
      page_title = driver.title
      Rails.logger.info "[GrabJWT] After wait: #{page_title}"
    end

    # Extract JWT from performance logs
    jwt_token = nil
    api_version = nil

    logs = driver.logs.get(:performance)
    Rails.logger.info "[GrabJWT] #{logs.size} CDP events"

    logs.each do |entry|
      log_entry = JSON.parse(entry.message)["message"] rescue next
      next unless log_entry["method"] == "Network.requestWillBeSent"

      request = log_entry.dig("params", "request") || next
      url = request["url"] || ""
      next unless url.include?(API_URL_PATTERN)

      headers = request["headers"] || {}
      if headers["X-Hydra-JWT"]
        jwt_token = headers["X-Hydra-JWT"]
        api_version = headers["X-Grab-Web-App-Version"]
        Rails.logger.info "[GrabJWT] Found JWT!"
        break
      end
    end

    # Extract cookies via CDP (more reliable than driver.manage when using proxy extension)
    browser_cookies = {}
    begin
      cdp_cookies = driver.execute_cdp("Network.getCookies", urls: ["https://food.grab.com", "https://portal.grab.com"])
      (cdp_cookies["cookies"] || []).each do |c|
        browser_cookies[c["name"]] = c["value"]
      end
      Rails.logger.info "[GrabJWT] Got #{browser_cookies.size} cookies via CDP"
    rescue => e
      Rails.logger.warn "[GrabJWT] CDP cookies failed: #{e.message}, trying driver.manage"
      driver.manage.all_cookies.each { |c| browser_cookies[c[:name]] = c[:value] }
    end

    if jwt_token
      save_credentials(jwt_token, api_version, browser_cookies)
      true
    else
      Rails.logger.error "[GrabJWT] JWT not found (title: #{page_title}, events: #{logs.size})"
      save_credentials(nil, nil, browser_cookies, error: "JWT not found") unless browser_cookies.empty?
      false
    end
  end

  def save_credentials(jwt_token, api_version, cookies, error: nil)
    data = {
      "cookies" => cookies,
      "jwt_token" => jwt_token,
      "api_version" => api_version || "uaf6yDMWlVv0CaTK5fHdB",
      "timestamp" => Time.current.utc.strftime("%Y-%m-%dT%H:%M:%S.000Z")
    }
    data["error"] = error if error

    File.write(Rails.root.join("storage", COOKIES_FILE), JSON.pretty_generate(data))
    File.write(Rails.root.join(COOKIES_FILE), JSON.pretty_generate(data)) rescue nil

    jwt_token ? Rails.logger.info("[GrabJWT] Saved JWT + #{cookies.size} cookies") :
                Rails.logger.warn("[GrabJWT] Saved #{cookies.size} cookies (no JWT)")
  end

  def cleanup(driver)
    driver&.quit rescue nil
    FileUtils.rm_rf(@user_data_dir) if @user_data_dir
    FileUtils.rm_rf(@ext_dir) if @ext_dir
  end
end
