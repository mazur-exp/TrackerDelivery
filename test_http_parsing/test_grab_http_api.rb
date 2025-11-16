#!/usr/bin/env ruby

require 'httparty'
require 'json'

class TestGrabApiParser
  include HTTParty
  base_uri 'https://portal.grab.com'

  headers({
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    'Accept' => 'application/json, text/plain, */*',
    'Accept-Language' => 'en',
    'x-country-code' => 'ID',
    'x-gfc-country' => 'ID',
    'Referer' => 'https://food.grab.com/',
    'Origin' => 'https://food.grab.com'
  })

  def initialize
    @timeout = 15
    @default_latlng = '-8.6705,115.2126'  # Bali coordinates
  end

  def test_parse(url)
    puts "\n=== Testing Grab API Parser ==="
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
      api_url = "/foodweb/guest/v2/merchants/#{merchant_id}"
      params = { latlng: @default_latlng }

      response = self.class.get(api_url, query: params, timeout: @timeout, headers: self.class.headers)

      if response.success?
        puts "✓ Successfully fetched API data (#{response.body.length} chars)"

        data = extract_data_from_api(response.parsed_response)
        duration = Time.now - start_time

        puts "✓ Parsing completed in #{duration.round(2)}s"
        display_results(data)

        return { success: true, data: data, duration: duration }
      else
        puts "✗ API error #{response.code}: #{response.message}"
        return { success: false, error: "HTTP #{response.code}" }
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
    # Grab URLs can be:
    # https://r.grab.com/g/6-20250920_121514_...
    # https://food.grab.com/id/en/restaurant/.../6-C65ZV62KVNEDPE

    # Pattern 1: Short URL with encoded merchant ID
    if url.include?('r.grab.com')
      # Follow redirect to get full URL
      response = HTTParty.get(url, follow_redirects: true, timeout: @timeout)
      url = response.request.last_uri.to_s
      puts "Redirected to: #{url}"
    end

    # Pattern 2: Extract from full URL
    # Example: .../6-C65ZV62KVNEDPE?sourceID=...
    match = url.match(/\/(\d+-[A-Z0-9]+)(\?|$)/)
    return match[1] if match

    # Pattern 3: Try to extract from query params
    match = url.match(/[?&]id=([\dA-Z0-9-]+)/)
    return match[1] if match

    nil
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

    # Extract address
    address = merchant['address'] || merchant['shortAddress']

    # Extract rating
    rating = merchant['rating']&.to_s

    # Extract status
    status = extract_status(merchant['openingHours'])

    {
      name: merchant['name'],
      address: address,
      rating: rating,
      review_count: merchant['reviewCount'],
      cuisines: cuisines,
      coordinates: coordinates,
      image_url: merchant['photoHref'],
      status: status,
      opening_hours: opening_hours
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

        days << {
          day: info[:order],
          day_name: info[:short],
          day_name_en: info[:full],
          hours_raw: hours_str,
          start_time: parsed[:start_time],
          end_time: parsed[:end_time],
          formatted: "#{info[:short]}: #{parsed[:start_time]}-#{parsed[:end_time]}"
        } if parsed
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

    # Display in specific order with formatting
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
  parser = TestGrabApiParser.new
  result = parser.test_parse(ARGV[0])
  puts "\nResult: #{result[:success] ? 'SUCCESS' : 'FAILED'}"
else
  puts "Usage: ruby test_grab_http_api.rb <grab_url>"
  puts "Example: ruby test_grab_http_api.rb 'https://r.grab.com/g/6-20250920_121514_...'"
end
