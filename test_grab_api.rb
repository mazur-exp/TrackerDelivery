#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

class GrabAPITester
  def initialize
    @base_url = "https://p.grab.com/delvplatformapi"
    @proxy_url = "https://food.grab.com/proxy/delvplatformapi"
    
    # Restaurant data from our previous analysis
    @restaurant_id = "6-C4J1HGK3N33WR2"
    @restaurant_lat = -8.637902
    @restaurant_lng = 115.157834
  end
  
  def test_coordinate_to_address
    puts "=" * 80
    puts "TESTING: Coordinate to Address API"
    puts "=" * 80
    
    # Try common API endpoints for reverse geocoding
    endpoints = [
      "/v1/geocode/reverse",
      "/geocode/reverse", 
      "/location/reverse",
      "/v2/geocode/reverse",
      "/reverse-geocode"
    ]
    
    endpoints.each do |endpoint|
      puts "\nTrying endpoint: #{endpoint}"
      
      [@base_url, @proxy_url].each do |base|
        url = "#{base}#{endpoint}"
        
        # Try GET request with query parameters
        params = "?lat=#{@restaurant_lat}&lng=#{@restaurant_lng}&latitude=#{@restaurant_lat}&longitude=#{@restaurant_lng}"
        
        puts "  Testing: #{url}#{params}"
        result = make_request("#{url}#{params}", :get)
        
        if result && !result.empty?
          puts "  ✅ SUCCESS: #{result}"
          return result
        else
          puts "  ❌ No data or error"
        end
      end
    end
    
    nil
  end
  
  def test_restaurant_by_id
    puts "\n" + "=" * 80
    puts "TESTING: Restaurant by ID API" 
    puts "=" * 80
    
    # Try common API endpoints for restaurant details
    endpoints = [
      "/v1/restaurants/#{@restaurant_id}",
      "/restaurants/#{@restaurant_id}",
      "/restaurant/#{@restaurant_id}",
      "/v2/restaurants/#{@restaurant_id}",
      "/merchant/#{@restaurant_id}",
      "/v1/merchant/#{@restaurant_id}",
      "/restaurants/details/#{@restaurant_id}"
    ]
    
    endpoints.each do |endpoint|
      puts "\nTrying endpoint: #{endpoint}"
      
      [@base_url, @proxy_url].each do |base|
        url = "#{base}#{endpoint}"
        
        puts "  Testing: #{url}"
        result = make_request(url, :get)
        
        if result && !result.empty?
          puts "  ✅ SUCCESS: #{result}"
          
          # Try to parse as JSON and look for address
          begin
            parsed = JSON.parse(result)
            if parsed.is_a?(Hash)
              address_data = find_address_in_data(parsed)
              if address_data
                puts "  🏠 Found address data: #{address_data}"
                return address_data
              end
            end
          rescue JSON::ParserError
            puts "  📝 Non-JSON response received"
          end
        else
          puts "  ❌ No data or error"
        end
      end
    end
    
    nil
  end
  
  def test_restaurant_search
    puts "\n" + "=" * 80
    puts "TESTING: Restaurant Search API"
    puts "=" * 80
    
    # Try searching by coordinates and restaurant name
    endpoints = [
      "/v1/restaurants/search",
      "/restaurants/search",
      "/search/restaurants", 
      "/v2/restaurants/search"
    ]
    
    search_params = [
      "?lat=#{@restaurant_lat}&lng=#{@restaurant_lng}&q=Prana Kitchen",
      "?latitude=#{@restaurant_lat}&longitude=#{@restaurant_lng}&query=Prana Kitchen",
      "?location=#{@restaurant_lat},#{@restaurant_lng}&name=Prana Kitchen"
    ]
    
    endpoints.each do |endpoint|
      search_params.each do |params|
        puts "\nTrying: #{endpoint}#{params}"
        
        [@base_url, @proxy_url].each do |base|
          url = "#{base}#{endpoint}#{params}"
          
          puts "  Testing: #{url}"
          result = make_request(url, :get)
          
          if result && !result.empty?
            puts "  ✅ SUCCESS: #{result[0..200]}..." if result.length > 200
            puts "  ✅ SUCCESS: #{result}" if result.length <= 200
          else
            puts "  ❌ No data or error"
          end
        end
      end
    end
  end
  
  private
  
  def make_request(url, method = :get, body = nil)
    begin
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http.read_timeout = 10
      http.open_timeout = 10
      
      case method
      when :get
        request = Net::HTTP::Get.new(uri)
      when :post
        request = Net::HTTP::Post.new(uri)
        request.body = body if body
      end
      
      # Add common headers
      request['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 14_7_1 like Mac OS X) AppleWebKit/605.1.15'
      request['Accept'] = 'application/json, text/plain, */*'
      request['Accept-Language'] = 'en-US,en;q=0.9'
      request['Content-Type'] = 'application/json' if method == :post
      
      response = http.request(request)
      
      case response.code.to_i
      when 200..299
        return response.body
      when 404
        puts "    404 - Endpoint not found"
        return nil
      when 401, 403
        puts "    #{response.code} - Authentication required"
        return nil
      else
        puts "    #{response.code} - #{response.message}"
        return nil
      end
      
    rescue => e
      puts "    Error: #{e.message}"
      return nil
    end
  end
  
  def find_address_in_data(data, path = "")
    case data
    when Hash
      data.each do |key, value|
        current_path = path.empty? ? key.to_s : "#{path}.#{key}"
        
        # Check if this looks like address data
        if key.to_s.downcase.match?(/address|street|location|area|district/) && 
           value.is_a?(String) && !value.empty?
          return "#{current_path}: #{value}"
        end
        
        # Recursively search in nested data
        result = find_address_in_data(value, current_path)
        return result if result
      end
    when Array
      data.each_with_index do |item, index|
        result = find_address_in_data(item, "#{path}[#{index}]")
        return result if result
      end
    end
    
    nil
  end
end

# Run the tests
tester = GrabAPITester.new

puts "🔍 Testing Grab API endpoints to find restaurant address"
puts "Restaurant: Prana Kitchen - Tibubeneng (#{tester.instance_variable_get(:@restaurant_id)})"
puts "Coordinates: #{tester.instance_variable_get(:@restaurant_lat)}, #{tester.instance_variable_get(:@restaurant_lng)}"
puts

# Test 1: Coordinate to address
address_result = tester.test_coordinate_to_address

# Test 2: Restaurant by ID  
restaurant_result = tester.test_restaurant_by_id

# Test 3: Restaurant search (bonus)
tester.test_restaurant_search

puts "\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80
puts "Coordinate API result: #{address_result || 'No success'}"
puts "Restaurant ID API result: #{restaurant_result || 'No success'}"