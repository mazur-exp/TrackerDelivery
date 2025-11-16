#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'
require 'http-cookie'

class TestGrabHttpParser
  include HTTParty

  headers({
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language' => 'en-US,en;q=0.5',
    'Accept-Encoding' => 'gzip, deflate, br',
    'Connection' => 'keep-alive',
    'Upgrade-Insecure-Requests' => '1',
    'Sec-Fetch-Dest' => 'document',
    'Sec-Fetch-Mode' => 'navigate',
    'Sec-Fetch-Site' => 'none'
  })

  def initialize(cookies_file: nil)
    @timeout = 15
    @cookie_jar = HTTP::CookieJar.new
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
    uri = URI.parse('https://food.grab.com/')
    data['cookies'].each do |name, value|
      cookie = HTTP::Cookie.new(
        name: name,
        value: value,
        domain: 'food.grab.com',
        path: '/'
      )
      @cookie_jar.add(cookie)
    end

    @cookies_initialized = true
    puts "✅ Loaded #{@cookie_jar.cookies.length} cookies from file"
  rescue => e
    puts "❌ Error loading cookies: #{e.message}"
  end
  
  def test_parse(url)
    puts "\n=== Testing Grab HTTP Parser ==="
    puts "URL: #{url}"
    start_time = Time.now

    begin
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

      response = HTTParty.get(url, options)

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

      if response.success?
        puts "✓ Successfully fetched page (#{response.body.length} chars)"

        data = extract_data_from_html(response.body)
        duration = Time.now - start_time

        puts "✓ Parsing completed in #{duration.round(2)}s"
        display_results(data)

        return { success: true, data: data, duration: duration }
      else
        puts "✗ HTTP error #{response.code}: #{response.message}"
        return { success: false, error: "HTTP #{response.code}" }
      end

    rescue => e
      duration = Time.now - start_time
      puts "✗ Error after #{duration.round(2)}s: #{e.class} - #{e.message}"
      return { success: false, error: e.message }
    end
  end
  
  private
  
  def extract_data_from_html(html_content)
    # Try JSON extraction first
    json_data = extract_json_data_from_scripts(html_content)
    return json_data if json_data
    
    # Fallback to DOM parsing
    doc = Nokogiri::HTML(html_content)
    extract_data_from_dom(doc)
  end
  
  def extract_json_data_from_scripts(html_content)
    doc = Nokogiri::HTML(html_content)
    scripts = doc.css('script')
    
    puts "Found #{scripts.count} script tags to analyze"
    
    scripts.each_with_index do |script, index|
      content = script.inner_html
      next if content.nil? || content.empty?
      
      # Same patterns as production parser
      json_patterns = [
        { pattern: '"props".*"ssrRestaurantData"', start: '{"props"' },
        { pattern: '"restaurant".*"name"', start: '{"restaurant"' },
        { pattern: '"pageProps".*"restaurant"', start: '{"pageProps"' }
      ]
      
      json_patterns.each do |pattern_info|
        if content.match(/#{pattern_info[:pattern]}/i)
          puts "Found potential JSON in script #{index + 1}"
          
          json_data = extract_json_from_script_content(content, pattern_info[:start])
          return json_data if json_data
        end
      end
    end
    
    puts "No valid JSON restaurant data found"
    nil
  end
  
  def extract_json_from_script_content(content, start_pattern)
    json_start = content.index(start_pattern)
    return nil unless json_start
    
    json_content = content[json_start..-1]
    
    # Find end of JSON object with proper brace counting
    brace_count = 0
    json_end = nil
    in_string = false
    escape_next = false
    
    json_content.each_char.with_index do |char, i|
      if escape_next
        escape_next = false
        next
      end
      
      if char == '\\'
        escape_next = true
        next
      end
      
      if char == '"' && !escape_next
        in_string = !in_string
        next
      end
      
      next if in_string
      
      case char
      when '{'
        brace_count += 1
      when '}'
        brace_count -= 1
        if brace_count == 0
          json_end = i
          break
        end
      end
    end
    
    return nil unless json_end
    
    json_data = json_content[0..json_end]
    
    begin
      parsed = JSON.parse(json_data)
      puts "Successfully parsed JSON data"
      
      # Extract restaurant data from different possible locations
      restaurant_data = parsed.dig("props", "pageProps", "ssrRestaurantData") ||
                       parsed.dig("restaurant") ||
                       parsed.dig("pageProps", "restaurant")
      
      if restaurant_data
        puts "Found restaurant data with keys: #{restaurant_data.keys.join(', ')}"
        return extract_restaurant_info_from_json(restaurant_data)
      else
        puts "JSON parsed but no restaurant data found"
        return nil
      end
    rescue JSON::ParserError => e
      puts "JSON parsing failed: #{e.message}"
      return nil
    end
  end
  
  def extract_restaurant_info_from_json(restaurant_data)
    # Extract cuisines
    cuisines = []
    if restaurant_data["cuisine"] && !restaurant_data["cuisine"].empty?
      cuisine_text = restaurant_data["cuisine"]
      cuisines = cuisine_text.split(/[,•·|&]/).map(&:strip).reject { |x| x.nil? || x.empty? }.first(3)
    end
    
    # Extract coordinates
    coordinates = nil
    if restaurant_data["latlng"] && !restaurant_data["latlng"].empty?
      coordinates = {
        latitude: restaurant_data["latlng"]["latitude"]&.to_f,
        longitude: restaurant_data["latlng"]["longitude"]&.to_f
      }
    end
    
    # Extract address
    address = restaurant_data["address"] || restaurant_data["shortAddress"]
    
    # Extract rating
    rating = restaurant_data["rating"]&.to_s
    
    {
      name: restaurant_data["name"],
      address: address,
      rating: rating,
      cuisines: cuisines,
      coordinates: coordinates,
      image_url: restaurant_data["photoHref"]
    }.compact
  end
  
  def extract_data_from_dom(doc)
    puts "Falling back to DOM extraction"

    # Extract name from h1 or title
    name = doc.css('h1').first&.text&.strip
    if !name || name.empty?
      title = doc.css('title').first&.text&.strip
      name = title&.split(' ⭐')&.first || title&.split(' | ')&.first
    end

    # Extract cuisines from h3 or meta description
    cuisines = []
    cuisine_element = doc.css('h3').first
    if cuisine_element
      cuisine_text = cuisine_element.text.strip
      cuisines = cuisine_text.split(',').map(&:strip).reject(&:empty?).first(3)
    end

    if cuisines.empty?
      meta_desc = doc.css('meta[name="description"]').first&.attribute('content')&.value
      if meta_desc && meta_desc.include?(',')
        cuisines = meta_desc.split(',').map(&:strip).first(3)
      end
    end

    # Extract rating from meta og:title or visible text
    rating = nil
    og_title = doc.css('meta[property="og:title"]').first&.attribute('content')&.value
    if og_title
      rating_match = og_title.match(/⭐\s*([\d.]+)/)
      rating = rating_match[1] if rating_match
    end

    # Extract image from og:image
    image_url = doc.css('meta[property="og:image"]').first&.attribute('content')&.value

    # Extract opening hours from text
    opening_hours = extract_opening_hours_from_dom(doc)

    # Extract status (open/closed)
    status = extract_status_from_dom(doc, opening_hours)

    {
      name: name,
      address: nil,
      rating: rating,
      review_count: nil,
      cuisines: cuisines,
      coordinates: nil,
      image_url: image_url,
      status: status,
      opening_hours: opening_hours
    }.compact
  end

  def extract_opening_hours_from_dom(doc)
    # Ищем "Opening Hours" и следующий за ним текст
    opening_hours_elements = doc.css('*').select { |el| el.text&.strip == 'Opening Hours' }

    opening_hours_elements.each do |element|
      # Ищем соседние элементы с временем
      parent = element.parent
      siblings = parent.css('*')

      siblings.each do |sibling|
        text = sibling.text.strip
        # Формат: "Today  11:00-22:00" или "11:00-22:00"
        if text.match(/\d{1,2}:\d{2}-\d{1,2}:\d{2}/)
          # Извлекаем время
          time_match = text.match(/(\d{1,2}:\d{2})-(\d{1,2}:\d{2})/)
          if time_match
            return [{
              day_name: 'Today',
              hours: text.strip,
              start_time: time_match[1],
              end_time: time_match[2],
              formatted: "Today: #{time_match[1]}-#{time_match[2]}"
            }]
          end
        end
      end
    end

    []
  end

  def extract_status_from_dom(doc, opening_hours)
    # Если есть opening hours с "Today", значит открыто
    if opening_hours&.any? && opening_hours.first[:day_name] == 'Today'
      return {
        is_open: true,
        status_text: 'open',
        displayed_hours: opening_hours.first[:hours],
        error: nil
      }
    end

    # Ищем текст "Closed" или "Open"
    page_text = doc.text.downcase
    if page_text.include?('closed now') || page_text.include?('currently closed')
      return {
        is_open: false,
        status_text: 'closed',
        error: nil
      }
    end

    {
      is_open: nil,
      status_text: 'unknown',
      error: 'Status not available in HTML'
    }
  end
  
  def display_results(data)
    puts "\n=== Extracted Data ==="
    if data.nil?
      puts "No data extracted"
      return
    end

    # Display in specific order
    puts "Name: #{data[:name]}" if data[:name]
    puts "Address: #{data[:address]}" if data[:address]

    if data[:rating]
      rating_text = data[:rating]
      rating_text += " (#{data[:review_count]} reviews)" if data[:review_count]
      puts "Rating: #{rating_text}"
    end

    puts "Cuisines: #{data[:cuisines].join(', ')}" if data[:cuisines]&.any?

    if data[:coordinates]
      puts "Coordinates: #{data[:coordinates][:latitude]}, #{data[:coordinates][:longitude]}"
    end

    puts "Image_url: #{data[:image_url]}" if data[:image_url]
    puts "Status: #{data[:status]}" if data[:status]

    # Display opening hours
    if data[:opening_hours]&.any?
      puts "\nOpening Hours:"
      data[:opening_hours].each do |hours|
        puts "  #{hours[:formatted]}"
      end
    end

    # Check if sufficient for onboarding
    sufficient = data[:name] && !data[:name].empty? &&
                ((data[:address] && !data[:address].empty?) || data[:coordinates])
    puts "\nSufficient for onboarding: #{sufficient ? '✓' : '✗'}"
  end
end

# Test URLs (add real Grab URLs here)
test_urls = [
  # Add real Grab restaurant URLs for testing
  "https://food.grab.com/id/en/restaurant/..."
]

if ARGV.length > 0
  # Test single URL from command line
  # Load cookies from grab_cookies.json if exists
  cookies_file = File.join(File.dirname(__dir__), 'grab_cookies.json')
  if File.exist?(cookies_file)
    puts "✅ Found cookies file: grab_cookies.json"
  end

  parser = TestGrabHttpParser.new(
    cookies_file: File.exist?(cookies_file) ? cookies_file : nil
  )
  result = parser.test_parse(ARGV[0])
  puts "\nResult: #{result[:success] ? 'SUCCESS' : 'FAILED'}"
else
  puts "Usage: ruby test_grab_http.rb <grab_url>"
  puts "Example: ruby test_grab_http.rb 'https://r.grab.com/g/6-20250920_...'"
end