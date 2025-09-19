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

# Load service
require_relative 'app/services/grab_parser_service'

puts "🧪 Testing Grab Parser with Coordinates Output"
puts "=" * 50
puts "🎯 Target: Prana Kitchen - Tibubeneng"
puts "📍 Expected coordinates as address: -8.637902, 115.157834"
puts ""

test_url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"

puts "🚀 Starting parser test..."
puts "URL: #{test_url}"
puts ""

begin
  parser = GrabParserService.new
  start_time = Time.now
  
  result = parser.parse(test_url)
  
  duration = Time.now - start_time
  
  if result
    puts "✅ PARSING SUCCESS! (#{duration.round(2)}s)"
    puts "=" * 30
    
    puts "🏪 Restaurant Name: #{result[:name] || 'Not found'}"
    puts "🏠 Address: #{result[:address] || 'Not found'}"
    
    if result[:coordinates]
      puts "📍 Coordinates Object:"
      puts "   Latitude:  #{result[:coordinates][:latitude]}"
      puts "   Longitude: #{result[:coordinates][:longitude]}"
    else
      puts "📍 Coordinates Object: Not found"
    end
    
    puts "🍽️  Cuisine: #{result[:cuisines]&.join(', ') || 'Not found'}"
    puts "⭐ Rating: #{result[:rating] || 'Not found'}"
    
    if result[:status]
      status_text = result[:status][:is_open] ? 'OPEN' : 'CLOSED'
      puts "🚪 Status: #{status_text}"
    end
    
    puts ""
    puts "=" * 30
    puts "🔍 ADDRESS VERIFICATION"
    
    if result[:address]
      if result[:address].match?(/^-?\d+\.\d+, -?\d+\.\d+$/)
        puts "✅ Address contains coordinates format!"
        puts "📍 Format: latitude, longitude"
      else
        puts "⚠️  Address is not in coordinates format"
        puts "📝 Address: #{result[:address]}"
      end
    else
      puts "❌ No address found"
    end
    
  else
    puts "❌ PARSING FAILED!"
    puts "No data returned from parser"
  end
  
rescue => e
  puts "💥 PARSING ERROR!"
  puts "Error: #{e.class} - #{e.message}"
end

puts ""
puts "=" * 50
puts "🏁 Test completed!"
puts ""
puts "📋 Expected result:"
puts "  Address should be: '-8.637902, 115.157834'"
puts "  Coordinates object should contain latitude and longitude"