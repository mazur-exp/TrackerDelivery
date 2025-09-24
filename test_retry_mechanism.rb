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

  def debug(message)
    puts "[DEBUG] #{message}"
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

class Array
  def blank?
    self.empty?
  end

  def present?
    !blank?
  end
end

class Time
  def self.current
    Time.now
  end
end

require_relative 'app/services/grab_parser_service'

puts "🔧 RETRY MECHANISM TEST"
puts "=" * 50

test_url = "https://r.grab.com/g/6-20250920_121514_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C65ZV62KVNEDPE"

puts "Testing URL: #{test_url}"
puts "-" * 50

start_time = Time.now
begin
  parser = GrabParserService.new
  result = parser.parse(test_url)
  duration = Time.now - start_time

  if result
    puts "✅ SUCCESS (#{duration.round(2)}s)"
    puts "   🏪 Name: #{result[:name]}"
    puts "   📍 Address: #{result[:address] || 'N/A'}"
    puts "   🍽️  Cuisines: #{result[:cuisines]&.join(', ') || 'N/A'}"
    puts "   ⭐ Rating: #{result[:rating] || 'N/A'}"
    puts "   🕐 Hours: #{result[:working_hours]&.length || 0} entries"
    puts "   🖼️  Image: #{result[:image_url] ? 'Yes' : 'No'}"
    puts "   📱 Status: #{result[:status][:status_text] if result[:status]}"
  else
    puts "❌ FAILED (#{duration.round(2)}s)"
    puts "   Parser returned nil"
  end
rescue => e
  duration = Time.now - start_time
  puts "💥 EXCEPTION (#{duration.round(2)}s)"
  puts "   Error: #{e.message}"
  puts "   Class: #{e.class}"
end

puts "=" * 50
