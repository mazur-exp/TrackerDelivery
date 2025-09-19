#!/usr/bin/env ruby

# Mock Rails logger for testing
class MockLogger
  def info(message)
    puts "[INFO] #{message}"
  end
  
  def error(message)
    puts "[ERROR] #{message}"
  end
  
  def warn(message)
    puts "[WARN] #{message}"
  end
end

module Rails
  def self.logger
    @logger ||= MockLogger.new
  end
end

# Mock ActiveSupport methods
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

require_relative 'app/services/grab_parser_service'

# Test the Grab parser with Prana Kitchen mobile URL
test_url = "https://r.grab.com/g/6-20250919_142036_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"

puts "Testing Grab parser with URL: #{test_url}"
puts "=" * 80

parser = GrabParserService.new
result = parser.parse(test_url)

if result
  puts "SUCCESS! Parsed data:"
  puts "Name: #{result[:name]}"
  puts "Address: #{result[:address]}"
  puts "Cuisines: #{result[:cuisines].inspect}"
  puts "Rating: #{result[:rating]}"
  puts "Working Hours: #{result[:working_hours].inspect}"
  puts "Image URL: #{result[:image_url]}"
else
  puts "FAILED! Parser returned nil"
end
