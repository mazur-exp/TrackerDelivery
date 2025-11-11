#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'
require 'http-cookie'
require_relative 'proxy_manager'

class TestGojekHttpParser
  include HTTParty
  
  headers({
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.9,id;q=0.8',
    'Accept-Encoding' => 'gzip, deflate, br',
    'Connection' => 'keep-alive',
    'Upgrade-Insecure-Requests' => '1',
    'Sec-Fetch-Dest' => 'document',
    'Sec-Fetch-Mode' => 'navigate',
    'Sec-Fetch-Site' => 'none',
    'Sec-Fetch-User' => '?1',
    'Cache-Control' => 'max-age=0'
  })
  
  def initialize(proxy_manager: nil, cookies_file: nil)
    @timeout = 15
    @proxy_manager = proxy_manager
    @max_retries = 3
    @cookie_jar = HTTP::CookieJar.new  # Cookie support for WAF bypass
    @cookies_initialized = false

    # Load cookies from file if provided
    if cookies_file && File.exist?(cookies_file)
      load_cookies_from_file(cookies_file)
    end
  end

  def load_cookies_from_file(filepath)
    puts "🍪 Loading cookies from #{filepath}..."

    data = JSON.parse(File.read(filepath))

    # Add cookies to jar
    uri = URI.parse('https://gofood.co.id/')
    data['cookies'].each do |name, value|
      cookie = HTTP::Cookie.new(
        name: name,
        value: value,
        domain: 'gofood.co.id',
        path: '/'
      )
      @cookie_jar.add(cookie)
    end

    @cookies_initialized = true
    puts "✅ Loaded #{@cookie_jar.cookies.length} cookies from file"
  rescue => e
    puts "❌ Error loading cookies: #{e.message}"
  end

  def initialize_cookies(with_proxy: true)
    # Get WAF cookies from homepage
    puts "🍪 Initializing WAF cookies from GoFood homepage..."

    options = {
      timeout: @timeout,
      headers: self.class.headers.dup,
      follow_redirects: true
    }

    # IMPORTANT: Get cookies through the SAME proxy that will be used for requests
    if @proxy_manager && with_proxy
      proxy_options = @proxy_manager.to_httparty_format
      options.merge!(proxy_options) if proxy_options
      puts "  → Using proxy #{@proxy_manager.current_index + 1}/#{@proxy_manager.proxies.length}"
    end

    # Visit homepage to get w_tsfp cookie
    response = HTTParty.get('https://gofood.co.id/', options)

    if response.headers['set-cookie']
      uri = URI.parse('https://gofood.co.id/')
      [response.headers['set-cookie']].flatten.each do |cookie_string|
        HTTP::Cookie.parse(cookie_string, uri) do |cookie|
          @cookie_jar.add(cookie)
        end
      end
      puts "✅ Initialized #{@cookie_jar.cookies.length} cookies"
      @cookies_initialized = true
      true
    else
      puts "⚠️  No cookies received from homepage"
      false
    end
  rescue => e
    puts "❌ Cookie initialization failed: #{e.message}"
    false
  end
  
  def resolve_gofood_link(short_url)
    # Resolve gofood.link JavaScript redirect to actual restaurant URL
    return short_url unless short_url.include?('gofood.link')

    puts "🔗 Resolving gofood.link redirect..."

    options = {
      timeout: @timeout,
      headers: self.class.headers.dup,
      follow_redirects: true
    }

    response = HTTParty.get(short_url, options)

    if response.body.include?('window.location.href')
      # Extract redirect URL from JavaScript: window.location.href = "URL";
      match = response.body.match(/window\.location\.href\s*=\s*["']([^"']+)["']/)
      if match && match[1] != ' # '
        redirect_url = match[1].strip.gsub('\\/', '/')  # Unescape slashes
        puts "✅ Resolved to: #{redirect_url}"
        return redirect_url
      end
    end

    puts "⚠️  Could not resolve gofood.link, using original URL"
    short_url
  end

  def test_parse(url, retry_count = 0)
    puts "\n=== Testing GoJek HTTP Parser ==="
    puts "URL: #{url}"
    start_time = Time.now

    begin
      # Initialize cookies on first request
      if !@cookies_initialized && retry_count == 0
        initialize_cookies
      end

      # Resolve gofood.link to actual URL
      resolved_url = resolve_gofood_link(url)

      # Prepare request options
      options = {
        timeout: @timeout,
        headers: self.class.headers.dup,
        follow_redirects: true
      }

      # Add cookies from jar
      cookie_header = @cookie_jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join('; ')
      if !cookie_header.empty?
        options[:headers]['Cookie'] = cookie_header
        puts "🍪 Using #{@cookie_jar.cookies.length} cookies"
      end

      # Add proxy if available
      if @proxy_manager
        proxy_options = @proxy_manager.to_httparty_format
        options.merge!(proxy_options) if proxy_options
        puts "🔄 Using proxy #{@proxy_manager.current_index + 1}/#{@proxy_manager.proxies.length}"
      end

      response = HTTParty.get(resolved_url, options)

      # Store cookies from response
      if response.headers['set-cookie']
        uri = URI.parse(response.request.last_uri.to_s)
        [response.headers['set-cookie']].flatten.each do |cookie_string|
          HTTP::Cookie.parse(cookie_string, uri) do |cookie|
            @cookie_jar.add(cookie)
          end
        end
        puts "🍪 Stored #{@cookie_jar.cookies.length} cookies"
      end

      # Increment proxy request count
      @proxy_manager&.increment_requests

      # Check for WAF block (small response)
      if response.success? && response.body.length < 1000
        puts "⚠️  WAF block detected (#{response.body.length} bytes), retrying with new proxy..."

        if retry_count < @max_retries && @proxy_manager
          @proxy_manager.force_rotate
          # Re-initialize cookies with new proxy
          @cookie_jar = HTTP::CookieJar.new
          @cookies_initialized = false
          sleep(2)  # Brief pause before retry
          return test_parse(url, retry_count + 1)
        else
          return { success: false, error: "WAF block - no proxies available" }
        end
      end

      if response.success?
        puts "✓ Successfully fetched page (#{response.body.length} chars)"

        data = extract_data_from_html(response.body, response.request.last_uri.to_s)
        duration = Time.now - start_time

        puts "✓ Parsing completed in #{duration.round(2)}s"
        display_results(data)

        return { success: true, data: data, duration: duration }
      elsif response.code == 403 || response.code == 429
        puts "✗ HTTP #{response.code} - rate limited or blocked"

        if retry_count < @max_retries && @proxy_manager
          puts "🔄 Rotating proxy and retrying..."
          @proxy_manager.force_rotate
          sleep(3)
          return test_parse(url, retry_count + 1)
        else
          return { success: false, error: "HTTP #{response.code} - retries exhausted" }
        end
      else
        puts "✗ HTTP error #{response.code}: #{response.message}"
        return { success: false, error: "HTTP #{response.code}" }
      end

    rescue => e
      duration = Time.now - start_time
      puts "✗ Error after #{duration.round(2)}s: #{e.class} - #{e.message}"

      if retry_count < @max_retries && @proxy_manager
        puts "🔄 Retrying with new proxy..."
        @proxy_manager.force_rotate
        sleep(2)
        return test_parse(url, retry_count + 1)
      end

      return { success: false, error: e.message }
    end
  end
  
  private
  
  def extract_data_from_html(html_content, final_url = nil)
    puts "Parsing HTML (#{html_content.length} chars)..."
    puts "Final URL: #{final_url}" if final_url

    # Try Next.js JSON first (much more reliable and complete)
    json_data = extract_from_nextjs_json(html_content)
    if json_data && json_data[:name]
      puts "✅ Extracted data from Next.js JSON"
      return json_data
    end

    # Fallback to DOM parsing
    puts "⚠️  Falling back to DOM parsing (limited data quality)"
    doc = Nokogiri::HTML(html_content)

    {
      name: extract_restaurant_name_from_html(doc),
      address: extract_address_from_html(doc),
      cuisines: extract_cuisines_from_html(doc),
      rating: extract_rating_from_html(doc),
      image_url: extract_image_url_from_html(doc),
      status: extract_status_from_html(doc)
    }.compact
  end
  
  def extract_restaurant_name_from_html(doc)
    # Same selectors as production parser
    selectors = [
      'h1[data-testid="merchant-name"]',
      "h1.merchant-name", 
      "h1",
      '[data-testid="merchant-name"]',
      ".merchant-name",
      ".restaurant-name",
      "h2.text-gf-content-primary.gf-label-l"
    ]
    
    selectors.each do |selector|
      element = doc.css(selector).first
      if element && element.text.strip.length > 3
        puts "Found name with selector #{selector}: '#{element.text.strip}'"
        return element.text.strip
      end
    end
    
    # Try extracting from title tag
    title_element = doc.css('title').first
    if title_element
      title = title_element.text.strip
      # GoJek titles often have format "Restaurant Name | GoFood"
      name = title.split(' | ').first&.strip
      return name if name && name.length > 3
    end
    
    puts "Could not find restaurant name"
    nil
  end
  
  def extract_address_from_html(doc)
    selectors = [
      '[data-testid="merchant-address"]',
      ".merchant-address",
      ".address",
      ".restaurant-address",
      '[class*="address"]'
    ]

    selectors.each do |selector|
      element = doc.css(selector).first
      if element && !element.text.strip.empty?
        address = element.text.strip
        puts "Found address with selector #{selector}: '#{address}'"
        return address
      end
    end

    # Try meta tags - gofood.link format: "Cuisines, Address"
    meta_desc = doc.css('meta[name="description"]').first&.attribute('content')&.value&.strip ||
                doc.css('meta[property="og:description"]').first&.attribute('content')&.value&.strip

    if meta_desc && !meta_desc.empty?
      # Split cuisines and address
      address = extract_address_from_meta_description(meta_desc)
      if address
        puts "Found address from meta description: '#{address}'"
        return address
      end
    end

    # Try JSON-LD
    json_ld_address = extract_address_from_json_ld(doc)

    if json_ld_address
      puts "Found address in JSON-LD: '#{json_ld_address}'"
      return json_ld_address
    end

    puts "Could not find restaurant address"
    nil
  end

  def extract_cuisines_from_meta_description(description)
    # Format: "Cuisine1, Cuisine2 ADDRESS, ..."
    # Cuisines are before address patterns

    parts = description.split(',').map(&:strip)

    # Find where address starts
    cuisines = []
    parts.each do |part|
      # Stop if entire part is address
      if part.match?(/\bJl\./i) ||                 # Jalan
         part.match?(/\bNo\.\s*\d+/) ||            # No.22
         part.match?(/Kec\.|Kab\.|Kabupaten|Kecamatan/i)  # District names
        break
      end

      # Clean part from address fragments within it
      clean_part = part.dup

      # Remove HTML entities first
      clean_part.gsub!(/&#?\w+;/, '')

      # Remove plus codes (F49R+MFW or F49RMFW if entity was decoded)
      clean_part.gsub!(/ [A-Z0-9]{4}[\+]?[A-Z0-9]{3,4}/, '')

      clean_part = clean_part.strip

      # Skip if empty after cleaning
      next if clean_part.empty?

      # Skip if too long (likely address fragment)
      next if clean_part.length > 30

      cuisines << clean_part
    end

    # Take first 3 cuisines max
    cuisines.first(3)
  end

  def extract_address_from_meta_description(description)
    # Format: "Cuisine1, Cuisine2 ADDRESS_PATTERN, ..."
    # Address typically starts with: Jl./JL., street name, or location code (F49R+MFW)

    # Look for common address patterns
    address_start_patterns = [
      / [A-Z0-9]+\+[A-Z0-9]+,/,  # Plus code: F49R+MFW
      / Jl\./i,                     # Jalan
      / JL\./,                      # JL.
      / No\.\s*\d+/                 # No.22
    ]

    address_start_patterns.each do |pattern|
      match = description.match(pattern)
      if match
        # Everything from the match onwards is the address
        address_start_index = match.begin(0)
        return description[address_start_index..-1].strip
      end
    end

    # Fallback: if description has comma-separated parts, take from 3rd part onwards
    parts = description.split(',').map(&:strip)
    if parts.length > 2
      # First 2 are likely cuisines, rest is address
      return parts[2..-1].join(', ')
    end

    description
  end
  
  def extract_cuisines_from_html(doc)
    cuisines = []
    
    # Try specific GoJek cuisine selectors
    cuisine_selectors = [
      "p.text-gf-content-secondary.line-clamp-1",
      "p[class*='text-gf-content-secondary']",
      ".cuisine-tags .tag",
      ".categories .category"
    ]
    
    cuisine_selectors.each do |selector|
      elements = doc.css(selector)
      elements.each do |element|
        text = element.text.strip
        if text.include?(",") && text.length > 5 && text.length < 100
          # Likely contains cuisine information
          found_cuisines = text.split(/[,•·|&]/).map(&:strip).reject { |x| x.nil? || x.empty? }.first(3)
          if found_cuisines.any?
            puts "Found cuisines with selector #{selector}: #{found_cuisines.join(', ')}"
            cuisines = found_cuisines
            break
          end
        end
      end
      break if cuisines.any?
    end
    
    # Try meta description (gofood.link format: "Cuisines Address")
    if cuisines.empty?
      meta_desc = doc.css('meta[name="description"]').first&.attribute('content')&.value ||
                  doc.css('meta[property="og:description"]').first&.attribute('content')&.value

      if meta_desc && meta_desc.include?(",")
        # Extract only cuisines (before address starts)
        cuisines = extract_cuisines_from_meta_description(meta_desc)
      end
    end
    
    if cuisines.any?
      puts "Found cuisines: #{cuisines.join(', ')}"
      return cuisines
    else
      puts "Could not find cuisine information"
      return []
    end
  end
  
  def extract_rating_from_html(doc)
    rating_selectors = [
      '[data-testid="rating-value"]',
      ".rating-value",
      ".restaurant-rating .number",
      ".rating-number",
      '[class*="rating"]'
    ]
    
    rating_selectors.each do |selector|
      element = doc.css(selector).first
      if element
        text = element.text.strip
        if text.match?(/^\d+\.?\d*$/) && text.to_f > 0 && text.to_f <= 5
          puts "Found rating with selector #{selector}: '#{text}'"
          return text
        end
      end
    end
    
    # Look for rating in meta tags
    meta_rating = doc.css('meta[property="rating"]').first&.attribute('content')&.value ||
                  doc.css('meta[name="rating"]').first&.attribute('content')&.value
    
    if meta_rating && meta_rating.match?(/^\d+\.?\d*$/)
      puts "Found rating in meta: '#{meta_rating}'"
      return meta_rating
    end
    
    # Look in JSON-LD
    json_ld_rating = extract_rating_from_json_ld(doc)
    if json_ld_rating
      puts "Found rating in JSON-LD: '#{json_ld_rating}'"
      return json_ld_rating.to_s
    end
    
    puts "Could not find rating - might be 'NEW' restaurant"
    "NEW"
  end
  
  def extract_image_url_from_html(doc)
    image_selectors = [
      'img[data-testid="merchant-image"]',
      '.merchant-image img',
      '.restaurant-image img',
      'meta[property="og:image"]'
    ]
    
    image_selectors.each do |selector|
      if selector.include?('meta')
        element = doc.css(selector).first
        if element
          url = element.attribute('content')&.value
          if url && url.start_with?('http')
            puts "Found image URL in meta: '#{url}'"
            return url
          end
        end
      else
        element = doc.css(selector).first
        if element
          url = element.attribute('src')&.value
          if url && url.start_with?('http')
            puts "Found image URL: '#{url}'"
            return url
          end
        end
      end
    end
    
    puts "Could not find restaurant image"
    nil
  end
  
  def extract_status_from_html(doc)
    status_selectors = [
      "div[class*='status']",
      "span[class*='status']",
      "div[class*='tutup']",  # "tutup" = closed in Indonesian
      "div[class*='buka']",   # "buka" = open in Indonesian
      "div[class*='open']",
      "div[class*='close']"
    ]
    
    status_selectors.each do |selector|
      elements = doc.css(selector)
      elements.each do |element|
        text = element.text.strip.downcase
        
        # Check Indonesian status words
        if text.include?("tutup") || text.include?("closed")
          return {
            is_open: false,
            status_text: "closed",
            error: nil
          }
        elsif text.include?("buka") || text.include?("open")
          return {
            is_open: true,
            status_text: "open", 
            error: nil
          }
        end
      end
    end
    
    puts "Could not determine status from static HTML"
    {
      is_open: nil,
      status_text: "unknown",
      error: "Status not available in static HTML"
    }
  end
  
  def extract_address_from_json_ld(doc)
    json_ld_scripts = doc.css('script[type="application/ld+json"]')
    json_ld_scripts.each do |script|
      begin
        data = JSON.parse(script.inner_html)
        if data['@type'] == 'Restaurant' && data['address'] && !data['address'].empty?
          if data['address'].is_a?(Hash)
            return "#{data['address']['streetAddress']}, #{data['address']['addressLocality']}"
          else
            return data['address']
          end
        end
      rescue JSON::ParserError
        next
      end
    end
    nil
  end
  
  def extract_rating_from_json_ld(doc)
    json_ld_scripts = doc.css('script[type="application/ld+json"]')
    json_ld_scripts.each do |script|
      begin
        data = JSON.parse(script.inner_html)
        if data['@type'] == 'Restaurant' && data['aggregateRating'] && !data['aggregateRating'].empty?
          rating = data.dig('aggregateRating', 'ratingValue')
          return rating.to_f if rating && rating.to_f > 0
        end
      rescue JSON::ParserError
        next
      end
    end
    nil
  end
  
  def extract_from_nextjs_json(html_content)
    # Search for Next.js __NEXT_DATA__ script tag
    puts "Searching for Next.js __NEXT_DATA__ script..."

    # Find __NEXT_DATA__ script tag
    script_start = html_content.index('<script id="__NEXT_DATA__"')

    unless script_start
      puts "Could not find __NEXT_DATA__ script tag"
      return nil
    end

    # Find the JSON content inside the script tag
    json_start_marker = html_content.index('>', script_start)
    unless json_start_marker
      puts "Could not find script content start"
      return nil
    end

    # Extract content between <script...> and </script>
    json_start = json_start_marker + 1
    script_end = html_content.index('</script>', json_start)

    unless script_end
      puts "Could not find script tag end"
      return nil
    end

    json_content = html_content[json_start...script_end].strip
    puts "Found __NEXT_DATA__ script with #{json_content.length} chars"

    begin
      parsed = JSON.parse(json_content)
      outlet = parsed.dig('props', 'pageProps', 'outlet')

      unless outlet
        puts "No outlet data in JSON"
        return nil
      end

      # Extract cuisines from tags (taxonomy=2)
      cuisines = []
      if outlet['core'] && outlet['core']['tags']
        cuisines = outlet['core']['tags']
          .select { |tag| tag['taxonomy'] == 2 }
          .map { |tag| tag['displayName'] }
          .compact
          .first(3)
      end

      # Extract address from rows array
      address = nil
      if outlet['core'] && outlet['core']['address'] && outlet['core']['address']['rows']
        rows = outlet['core']['address']['rows'].compact.reject(&:empty?)
        address = rows.join(', ') unless rows.empty?
      end

      # Extract status from core.status (1 = OPEN, 2 = CLOSED)
      core_status = outlet.dig('core', 'status')
      is_open = core_status == 1

      status = {
        is_open: is_open,
        status_text: is_open ? 'open' : 'closed',
        core_status: core_status,
        deliverable: outlet.dig('delivery', 'deliverable'),  # Distance-based availability
        error: nil
      }

      puts "Found Next.js JSON with outlet data"

      return {
        name: outlet.dig('core', 'displayName'),
        address: address,
        rating: outlet.dig('ratings', 'average')&.to_s,
        cuisines: cuisines,
        image_url: outlet.dig('media', 'coverImgUrl'),
        status: status
      }.compact

    rescue JSON::ParserError => e
      puts "JSON parsing failed: #{e.message}"
      return nil
    end
  end

  def display_results(data)
    puts "\n=== Extracted Data ==="
    if data.nil?
      puts "No data extracted"
      return
    end
    
    data.each do |key, value|
      if value.is_a?(Array)
        puts "#{key.capitalize}: #{value.join(', ')}"
      elsif value.is_a?(Hash)
        puts "#{key.capitalize}: #{value}"
      else
        puts "#{key.capitalize}: #{value}"
      end
    end
    
    # Check if sufficient for onboarding
    sufficient = data[:name] && !data[:name].empty? && 
                ((data[:address] && !data[:address].empty?) || (data[:rating] && !data[:rating].empty?))
    puts "\nSufficient for onboarding: #{sufficient ? '✓' : '✗'}"
  end
end

# Test URLs (add real GoJek URLs here)
test_urls = [
  # Add real GoJek restaurant URLs for testing
  "https://www.gojek.com/gofood/restaurant/..."
]

if ARGV.length > 0
  # Test single URL from command line
  # Initialize proxy manager if proxies_test.txt exists
  proxy_manager = nil
  proxy_file = File.join(__dir__, 'proxies_test.txt')
  if File.exist?(proxy_file)
    proxy_manager = ProxyManager.new(proxy_file)
    puts "✅ Loaded proxy manager with #{proxy_manager.proxies.length} proxies"
  end

  # Load cookies from gojek_cookies.json if exists
  cookies_file = File.join(File.dirname(__dir__), 'gojek_cookies.json')
  if File.exist?(cookies_file)
    puts "✅ Found cookies file: gojek_cookies.json"
  end

  parser = TestGojekHttpParser.new(
    proxy_manager: proxy_manager,
    cookies_file: File.exist?(cookies_file) ? cookies_file : nil
  )
  result = parser.test_parse(ARGV[0])
  puts "\nResult: #{result[:success] ? 'SUCCESS' : 'FAILED'}"
else
  puts "Usage: ruby test_gojek_http.rb <gojek_url>"
  puts "Example: ruby test_gojek_http.rb 'https://gofood.link/a/...'"
end