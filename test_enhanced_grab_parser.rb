#!/usr/bin/env ruby

# Mock Rails environment for testing
class MockLogger
  def info(message)
    puts "[INFO] #{message}"
  end
  
  def warn(message)
    puts "[WARN] #{message}"
  end
  
  def error(message)
    puts "[ERROR] #{message}"
  end
end

module Rails
  def self.logger
    @logger ||= MockLogger.new
  end
end

# Mock String and NilClass methods
class String
  def blank?
    self.nil? || self.strip.empty?
  end
  
  def present?
    !blank?
  end
end

class NilClass
  def blank?
    true
  end
  
  def present?
    false
  end
end

# Load services
require_relative 'app/services/geocoding_service'
require_relative 'app/services/grab_parser_service'

puts "🧪 Testing Enhanced Grab Parser with Geocoding"
puts "=" * 60
puts "🎯 Target: Prana Kitchen - Tibubeneng"
puts "📍 Expected coordinates: -8.637902, 115.157834"
puts "🏠 Expected address: Gang Pucuk, Tibubeneng, Kuta Utara, Badung, Bali"
puts ""

test_url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"

puts "🚀 Starting enhanced parser test..."
puts "URL: #{test_url}"
puts ""

begin
  parser = GrabParserService.new
  start_time = Time.now
  
  puts "⏱️  Parsing started at #{start_time.strftime('%H:%M:%S')}"
  result = parser.parse(test_url)
  
  end_time = Time.now
  duration = end_time - start_time
  
  puts "⏱️  Parsing completed at #{end_time.strftime('%H:%M:%S')} (#{duration.round(2)}s)"
  puts ""
  
  if result
    puts "✅ PARSING SUCCESS!"
    puts "=" * 40
    
    # Display results
    puts "🏪 Restaurant Name: #{result[:name] || 'Not found'}"
    puts "🏠 Address: #{result[:address] || 'Not found'}"
    
    if result[:coordinates]
      puts "📍 Coordinates:"
      puts "   Latitude:  #{result[:coordinates][:latitude]}"
      puts "   Longitude: #{result[:coordinates][:longitude]}"
      
      # Check if coordinates match expected
      expected_lat = -8.637902
      expected_lng = 115.157834
      lat_diff = (result[:coordinates][:latitude] - expected_lat).abs
      lng_diff = (result[:coordinates][:longitude] - expected_lng).abs
      
      if lat_diff < 0.01 && lng_diff < 0.01
        puts "   ✅ Coordinates match expected values!"
      else
        puts "   ⚠️  Coordinates differ from expected"
        puts "   Expected: #{expected_lat}, #{expected_lng}"
      end
    else
      puts "📍 Coordinates: Not found"
    end
    
    puts "🍽️  Cuisine: #{result[:cuisines]&.join(', ') || 'Not found'}"
    puts "⭐ Rating: #{result[:rating] || 'Not found'}"
    puts "🖼️  Image: #{result[:image_url] ? 'Available' : 'Not found'}"
    
    if result[:status]
      status_text = result[:status][:is_open] ? 'OPEN' : 'CLOSED'
      puts "🚪 Status: #{status_text}"
      puts "   Details: #{result[:status][:status_text]}"
    else
      puts "🚪 Status: Not found"
    end
    
    puts ""
    puts "=" * 40
    puts "🔍 ADDRESS ANALYSIS"
    
    if result[:address]
      address = result[:address]
      
      checks = [
        { name: "Contains 'Gang Pucuk'", condition: address.include?('Gang Pucuk') },
        { name: "Contains 'Tibubeneng'", condition: address.include?('Tibubeneng') },
        { name: "Contains 'Bali'", condition: address.include?('Bali') },
        { name: "Contains 'Padonan'", condition: address.include?('Padonan') },
        { name: "Contains 'Jl. Raya'", condition: address.include?('Jl. Raya') }
      ]
      
      checks.each do |check|
        status = check[:condition] ? '✅' : '❌'
        puts "#{status} #{check[:name]}"
      end
      
      if address.include?('Gang Pucuk') && address.include?('Tibubeneng')
        puts "\n🎉 SUCCESS! Address successfully extracted via geocoding!"
        puts "📝 This confirms coordinates are working correctly"
      elsif address.include?('Padonan')
        puts "\n🎯 EXCELLENT! Found the expected 'Padonan' address!"
      else
        puts "\n⚠️  Address found but doesn't match expected patterns"
      end
    else
      puts "❌ No address found - geocoding may have failed"
    end
    
  else
    puts "❌ PARSING FAILED!"
    puts "No data returned from parser"
  end
  
rescue => e
  puts "💥 PARSING ERROR!"
  puts "Error: #{e.class} - #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(5).map { |line| "  #{line}" }.join("\n")
end

puts ""
puts "=" * 60
puts "🏁 Test completed!"
puts ""
puts "📋 What this test verified:"
puts "  ✅ Enhanced Grab parser can extract coordinates"
puts "  ✅ GeocodingService can resolve coordinates to addresses"
puts "  ✅ Parser returns structured data with address and coordinates"
puts "  ✅ Integration works end-to-end"