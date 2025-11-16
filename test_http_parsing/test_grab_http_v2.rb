#!/usr/bin/env ruby

require 'httparty'
require 'nokogiri'
require 'json'

class TestGrabHttpParserV2
  include HTTParty
  base_uri 'https://portal.grab.com'

  headers({
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    'Accept' => 'application/json, text/plain, */*',
    'Accept-Language' => 'en',
    'Referer' => 'https://food.grab.com/',
    'Origin' => 'https://food.grab.com',
    'sec-fetch-dest' => 'empty',
    'sec-fetch-mode' => 'cors',
    'sec-fetch-site' => 'same-site'
  })

  def initialize(cookies_file: nil)
    @timeout = 15
    @cookies_data = nil
    @default_latlng = '-8.6705,115.2126'  # Bali coordinates

    # Load cookies and JWT from file
    if cookies_file && File.exist?(cookies_file)
      load_cookies_from_file(cookies_file)
    end
  end

  def load_cookies_from_file(filepath)
    puts "🍪 Loading Grab cookies and JWT from #{filepath}..."

    @cookies_data = JSON.parse(File.read(filepath))

    puts "✅ Loaded #{@cookies_data['cookies'].length} cookies"
    puts "🔑 JWT token: #{@cookies_data['jwt_token'] ? 'Present' : 'Missing'}"
  rescue => e
    puts "❌ Error loading cookies: #{e.message}"
  end

  def test_parse(url)
    puts "\n=== Testing Grab API Parser V2 ==="
    puts "URL: #{url}"
    start_time = Time.now

    begin
      # Extract merchant ID from URL
      merchant_id = extract_merchant_id(url)
      unless merchant_id
        puts "✗ Could not extract merchant ID from URL"
        return { success: false, error: "Invalid URL format" }
      end

      puts "Merchant ID: #{merchant_id}"

      # Make API request
      data = fetch_from_api(merchant_id)

      if data
        duration = Time.now - start_time
        puts "✓ Parsing completed in #{duration.round(2)}s"
        display_results(data)

        return { success: true, data: data, duration: duration }
      else
        puts "✗ Failed to fetch data from API"
        return { success: false, error: "API request failed" }
      end

    rescue => e
      duration = Time.now - start_time
      puts "✗ Error after #{duration.round(2)}s: #{e.class} - #{e.message}"
      puts e.backtrace.first(3)
      return { success: false, error: e.message }
    end
  end

  private

  def extract_merchant_id(url)
    # Handle r.grab.com short URLs
    if url.include?('r.grab.com')
      response = HTTParty.get(url, follow_redirects: true, timeout: @timeout)
      url = response.request.last_uri.to_s
      puts "Redirected to: #{url}"
    end

    # Extract merchant ID from full URL
    # Example: .../6-C65ZV62KVNEDPE?sourceID=...
    match = url.match(/\/(\d+-[A-Z0-9]+)(\?|$)/)
    return match[1] if match

    # Try from query params
    match = url.match(/[?&]id=([\dA-Z0-9-]+)/)
    return match[1] if match

    nil
  end

  def fetch_from_api(merchant_id)
    api_url = "https://portal.grab.com/foodweb/guest/v2/merchants/#{merchant_id}"

    # Check if we have JWT token
    unless @cookies_data && @cookies_data['jwt_token']
      puts "⚠️  No JWT token available"
      return nil
    end

    # Prepare cookies string
    cookie_string = @cookies_data['cookies'].map { |k,v| "#{k}=#{v}" }.join('; ')

    # Prepare complete headers
    headers = {
      'accept' => 'application/json, text/plain, */*',
      'accept-language' => 'en',
      'cookie' => cookie_string,
      'origin' => 'https://food.grab.com',
      'referer' => 'https://food.grab.com/',
      'sec-ch-ua' => '"Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"',
      'sec-ch-ua-mobile' => '?0',
      'sec-ch-ua-platform' => '"macOS"',
      'sec-fetch-dest' => 'empty',
      'sec-fetch-mode' => 'cors',
      'sec-fetch-site' => 'same-site',
      'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
      'x-country-code' => 'ID',
      'x-gfc-country' => 'ID',
      'x-grab-web-app-version' => @cookies_data['api_version'] || 'uaf6yDMWlVv0CaTK5fHdB',
      'x-hydra-jwt' => @cookies_data['jwt_token']
    }

    # Prepare query params
    params = { latlng: @default_latlng }

    puts "🌐 Making API request to #{api_url}..."

    response = HTTParty.get(api_url, query: params, headers: headers, timeout: @timeout)

    if response.success?
      puts "✓ Successfully fetched API data (#{response.body.length} chars)"
      extract_data_from_api(response.parsed_response)
    else
      puts "✗ API error #{response.code}: #{response.message}"
      nil
    end
  end

  def extract_data_from_api(api_response)
    merchant = api_response['merchant']

    unless merchant
      puts "✗ No merchant data in API response"
      return nil
    end

    # Extract cuisines
    cuisines = []
    if merchant['cuisine'] && !merchant['cuisine'].empty?
      cuisines = merchant['cuisine'].split(',').map(&:strip).first(3)
    end

    # Extract coordinates
    coordinates = nil
    if merchant['latlng']
      coordinates = {
        latitude: merchant['latlng']['latitude']&.to_f,
        longitude: merchant['latlng']['longitude']&.to_f
      }
    end

    # Extract opening hours
    opening_hours = extract_opening_hours(merchant['openingHours'])

    # Extract status
    status = extract_status(merchant['openingHours'])

    # Extract address
    address = merchant['address'] || merchant['shortAddress']

    # Extract rating and review count
    rating = merchant['rating']&.to_s
    review_count = merchant['reviewCount']

    {
      name: merchant['name'],
      address: address,
      rating: rating,
      review_count: review_count,
      cuisines: cuisines,
      coordinates: coordinates,
      image_url: merchant['photoHref'],
      status: status,
      opening_hours: opening_hours,
      distance_km: merchant['distanceInKm']
    }.compact
  end

  def extract_opening_hours(opening_hours_data)
    return [] unless opening_hours_data

    days = []
    day_names = {
      'sun' => { full: 'Sunday', short: 'Minggu', order: 7 },
      'mon' => { full: 'Monday', short: 'Senin', order: 1 },
      'tue' => { full: 'Tuesday', short: 'Selasa', order: 2 },
      'wed' => { full: 'Wednesday', short: 'Rabu', order: 3 },
      'thu' => { full: 'Thursday', short: 'Kamis', order: 4 },
      'fri' => { full: 'Friday', short: 'Jumat', order: 5 },
      'sat' => { full: 'Saturday', short: 'Sabtu', order: 6 }
    }

    day_names.each do |key, info|
      if opening_hours_data[key]
        # Format: "11:00am-10:00pm" -> "11:00-22:00"
        hours_str = opening_hours_data[key]
        parsed = parse_hours_string(hours_str)

        if parsed
          days << {
            day: info[:order],
            day_name: info[:short],
            day_name_en: info[:full],
            hours_raw: hours_str,
            start_time: parsed[:start_time],
            end_time: parsed[:end_time],
            formatted: "#{info[:short]}: #{parsed[:start_time]}-#{parsed[:end_time]}"
          }
        end
      end
    end

    days.sort_by { |d| d[:day] }
  end

  def parse_hours_string(hours_str)
    # Parse "11:00am-10:00pm" to "11:00-22:00"
    return nil unless hours_str

    match = hours_str.match(/(\d+):(\d+)(am|pm)-(\d+):(\d+)(am|pm)/i)
    return nil unless match

    start_hour = match[1].to_i
    start_min = match[2]
    start_period = match[3].downcase
    end_hour = match[4].to_i
    end_min = match[5]
    end_period = match[6].downcase

    # Convert to 24-hour format
    start_hour = 0 if start_hour == 12 && start_period == 'am'
    start_hour += 12 if start_period == 'pm' && start_hour != 12

    end_hour = 0 if end_hour == 12 && end_period == 'am'
    end_hour += 12 if end_period == 'pm' && end_hour != 12

    {
      start_time: format('%02d:%02d', start_hour, start_min.to_i),
      end_time: format('%02d:%02d', end_hour, end_min.to_i)
    }
  end

  def extract_status(opening_hours_data)
    return { is_open: nil, status_text: 'unknown', error: 'No opening hours data' } unless opening_hours_data

    is_open = opening_hours_data['open'] == true

    {
      is_open: is_open,
      status_text: is_open ? 'open' : 'closed',
      displayed_hours: opening_hours_data['displayedHours'],
      error: nil
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

    puts "Distance: #{data[:distance_km]} km" if data[:distance_km]
    puts "Image_url: #{data[:image_url]}" if data[:image_url]
    puts "Status: #{data[:status]}" if data[:status]

    # Display opening hours
    if data[:opening_hours]&.any?
      puts "\nOpening Hours:"
      data[:opening_hours].each do |day|
        puts "  #{day[:formatted]}"
      end
    end

    # Check if sufficient for onboarding
    sufficient = data[:name] && !data[:name].empty? &&
                ((data[:address] && !data[:address].empty?) || data[:coordinates])
    puts "\nSufficient for onboarding: #{sufficient ? '✓' : '✗'}"
  end
end

# Test URLs
if ARGV.length > 0
  cookies_file = File.join(File.dirname(__dir__), 'grab_cookies.json')

  if File.exist?(cookies_file)
    puts "✅ Found cookies file: grab_cookies.json"
  else
    puts "❌ grab_cookies.json not found!"
    puts "Please create it with cookies and JWT token"
    exit 1
  end

  parser = TestGrabHttpParserV2.new(cookies_file: cookies_file)
  result = parser.test_parse(ARGV[0])
  puts "\nResult: #{result[:success] ? 'SUCCESS' : 'FAILED'}"
else
  puts "Usage: ruby test_grab_http_v2.rb <grab_url>"
  puts "Example: ruby test_grab_http_v2.rb 'https://r.grab.com/g/6-20250920_...'"
end
