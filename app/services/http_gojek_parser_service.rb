require "json"
require "open3"
require "uri"

class HttpGojekParserService
  SCRAPER_SCRIPT = Rails.root.join("lib", "gofood_scraper.js").to_s
  NODE_BIN = ENV.fetch("NODE_BIN", "node")
  PLAYWRIGHT_PATH = ENV.fetch("PLAYWRIGHT_PATH", nil)
  CACHE_TTL = 4.minutes
  SCRAPER_TIMEOUT = 120 # seconds

  def initialize
    @timeout = SCRAPER_TIMEOUT
  end

  def parse(url)
    Rails.logger.info "=== GoFood Scraping Browser Parser Starting for URL: #{url} ==="
    start_time = Time.current

    return nil if url.blank?

    begin
      # Resolve gofood.link short URLs first
      resolved_url = resolve_gofood_link(url)

      # Check cache first
      cached = read_cache(resolved_url)
      if cached
        duration = Time.current - start_time
        Rails.logger.info "GoFood SBR: Cache hit in #{duration.round(2)}s"
        return cached
      end

      # Call Node.js scraper
      data = call_scraper(resolved_url)

      if data
        # Cache the result
        write_cache(resolved_url, data)

        duration = Time.current - start_time
        Rails.logger.info "GoFood SBR: Completed in #{duration.round(2)}s - #{data[:name]}"
        return data
      else
        Rails.logger.error "GoFood SBR: No data returned for #{url}"
        return nil
      end

    rescue => e
      duration = Time.current - start_time
      Rails.logger.error "GoFood SBR: Error after #{duration.round(2)}s: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      return nil
    end
  end

  # Batch parse multiple URLs in one Scraping Browser session
  def parse_batch(urls)
    Rails.logger.info "=== GoFood Scraping Browser Batch: #{urls.length} URLs ==="
    start_time = Time.current

    return {} if urls.empty?

    # Resolve short URLs
    resolved_urls = urls.map { |url| resolve_gofood_link(url) }

    # Split into cached and uncached
    results = {}
    uncached_urls = []

    resolved_urls.each_with_index do |url, i|
      cached = read_cache(url)
      if cached
        results[urls[i]] = cached
      else
        uncached_urls << url
      end
    end

    if uncached_urls.any?
      Rails.logger.info "GoFood SBR: #{results.size} cached, #{uncached_urls.size} to fetch"
      batch_results = call_scraper_batch(uncached_urls)

      batch_results.each do |url, data|
        write_cache(url, data)
        # Map back to original URL
        original_idx = resolved_urls.index(url)
        results[urls[original_idx]] = data if original_idx
      end
    end

    duration = Time.current - start_time
    Rails.logger.info "GoFood SBR: Batch completed in #{duration.round(2)}s - #{results.size}/#{urls.length} success"
    results
  end

  # Resolve gofood.link short URLs to full gofood.co.id URLs
  def resolve_gofood_link(short_url)
    return short_url unless short_url.include?("gofood.link")

    Rails.logger.info "GoFood SBR: Resolving #{short_url}..."

    # gofood.link returns HTML with window.location.href JS redirect
    # but the actual redirect happens via server redirect or JS
    uri = URI.parse(short_url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 10) do |http|
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0"
      http.request(request)
    end

    # Check for Location header redirect
    if response.is_a?(Net::HTTPRedirection) && response["location"]
      Rails.logger.info "GoFood SBR: Resolved via redirect to #{response['location']}"
      return response["location"]
    end

    # Parse HTML for og:url or window.location
    if response.body
      # Try og:url meta tag
      og_match = response.body.match(/property="og:url"\s+content="([^"]+)"/)
      if og_match
        Rails.logger.info "GoFood SBR: Resolved via og:url to #{og_match[1]}"
        return og_match[1]
      end
    end

    # If we can't resolve, return original
    Rails.logger.warn "GoFood SBR: Could not resolve #{short_url}, using as-is"
    short_url
  rescue => e
    Rails.logger.warn "GoFood SBR: Error resolving #{short_url}: #{e.message}"
    short_url
  end

  # Check if extracted data is sufficient for onboarding
  def sufficient_for_onboarding?(data)
    return false unless data.is_a?(Hash)
    data[:name].present? && (data[:address].present? || data[:rating].present?)
  end

  private

  # Call Node.js scraper for a single URL
  def call_scraper(url)
    input = { url: url }.to_json
    raw_output = run_node_script(input)
    return nil unless raw_output

    parsed = JSON.parse(raw_output, symbolize_names: true)
    results = parsed[:results] || {}

    # Return first result (single URL mode)
    data = results.values.first
    return nil unless data

    symbolize_status(data)
  end

  # Call Node.js scraper for multiple URLs
  def call_scraper_batch(urls)
    input = { urls: urls }.to_json
    raw_output = run_node_script(input)
    return {} unless raw_output

    parsed = JSON.parse(raw_output, symbolize_names: true)
    results = parsed[:results] || {}

    if parsed[:errors]&.any?
      parsed[:errors].each { |e| Rails.logger.warn "GoFood SBR: #{e}" }
    end

    # Symbolize nested hashes
    results.transform_values { |data| symbolize_status(data) }
  end

  def run_node_script(input_json)
    env = {}
    env["NODE_PATH"] = PLAYWRIGHT_PATH if PLAYWRIGHT_PATH
    # Proxy config (defaults in scraper script, can override via ENV)
    env["PROXY_SERVER"] = ENV["PROXY_SERVER"] if ENV["PROXY_SERVER"]
    env["PROXY_USERNAME"] = ENV["PROXY_USERNAME"] if ENV["PROXY_USERNAME"]
    env["PROXY_PASSWORD"] = ENV["PROXY_PASSWORD"] if ENV["PROXY_PASSWORD"]

    cmd = [NODE_BIN, SCRAPER_SCRIPT, input_json]

    Rails.logger.info "GoFood SBR: Executing scraper..."

    stdout, stderr, status = Open3.capture3(env, *cmd, chdir: Rails.root.to_s)

    # Log stderr (scraper progress messages)
    stderr.each_line { |line| Rails.logger.info line.chomp } if stderr.present?

    unless status.success?
      Rails.logger.error "GoFood SBR: Scraper exited with code #{status.exitstatus}"
      Rails.logger.error "GoFood SBR: stderr: #{stderr}" if stderr.present?
      return nil
    end

    # stdout should be a single JSON line
    json_line = stdout.lines.last&.strip
    if json_line.blank? || !json_line.start_with?("{")
      Rails.logger.error "GoFood SBR: Invalid scraper output: #{stdout.first(200)}"
      return nil
    end

    json_line
  rescue Errno::ENOENT => e
    Rails.logger.error "GoFood SBR: Node.js not found: #{e.message}. Install Node.js or set NODE_BIN env var."
    nil
  rescue => e
    Rails.logger.error "GoFood SBR: Script execution error: #{e.class} - #{e.message}"
    nil
  end

  # Ensure status hash has symbol keys for compatibility with monitoring worker
  def symbolize_status(data)
    return nil unless data

    if data[:status].is_a?(Hash)
      data[:status] = data[:status].transform_keys(&:to_sym)
    end

    if data[:open_periods].is_a?(Array)
      data[:open_periods] = data[:open_periods].map { |p| p.transform_keys(&:to_sym) }
    end

    if data[:working_hours].is_a?(Array)
      data[:working_hours] = data[:working_hours].map { |p| p.transform_keys(&:to_sym) }
    end

    data
  end

  # --- Cache (file-based, per-URL) ---

  def cache_dir
    @cache_dir ||= Rails.root.join("tmp", "gofood_cache").tap { |d| FileUtils.mkdir_p(d) }
  end

  def cache_key(url)
    Digest::MD5.hexdigest(url)
  end

  def read_cache(url)
    file = cache_dir.join("#{cache_key(url)}.json")
    return nil unless File.exist?(file)

    data = JSON.parse(File.read(file), symbolize_names: true)
    cached_at = Time.parse(data[:cached_at]) rescue nil
    return nil unless cached_at && (Time.current - cached_at) < CACHE_TTL

    Rails.logger.info "GoFood SBR: Cache hit for #{url} (#{((Time.current - cached_at) / 60).round(1)}min old)"
    data[:data]
  rescue => e
    Rails.logger.warn "GoFood SBR: Cache read error: #{e.message}"
    nil
  end

  def write_cache(url, data)
    file = cache_dir.join("#{cache_key(url)}.json")
    cache_entry = { "cached_at" => Time.current.iso8601, "url" => url, "data" => deep_stringify(data) }
    File.write(file, JSON.generate(cache_entry))
  rescue => e
    Rails.logger.warn "GoFood SBR: Cache write error: #{e.message}"
  end

  def deep_stringify(obj)
    case obj
    when Hash then obj.transform_keys(&:to_s).transform_values { |v| deep_stringify(v) }
    when Array then obj.map { |v| deep_stringify(v) }
    else obj
    end
  end
end
