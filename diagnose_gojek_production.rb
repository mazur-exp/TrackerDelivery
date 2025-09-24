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

require_relative 'app/services/gojek_parser_service'

puts "🔧 GOJEK PRODUCTION DIAGNOSIS"
puts "=" * 60

# Test environment diagnosis
puts "\n📋 ENVIRONMENT CHECK:"
puts "-" * 30

chrome_paths = [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", # Mac
  "/usr/bin/google-chrome-stable", # Linux
  "/usr/bin/google-chrome", # Linux
  "/usr/bin/chromium", # Linux
  "/usr/bin/chromium-browser" # Linux
]

chromedriver_paths = [
  "/opt/homebrew/bin/chromedriver", # Mac Homebrew
  "/usr/local/bin/chromedriver",
  "/usr/bin/chromedriver",
  "/usr/lib/chromium/chromedriver",
  "/usr/lib/chromium-browser/chromedriver"
]

puts "🔍 Chrome Binary Search:"
chrome_found = nil
chrome_paths.each do |path|
  if File.exist?(path) && File.executable?(path)
    puts "  ✅ FOUND: #{path}"
    chrome_found = path
    break
  else
    puts "  ❌ NOT FOUND: #{path}"
  end
end

puts "\n🔍 ChromeDriver Search:"
chromedriver_found = nil
chromedriver_paths.each do |path|
  if File.exist?(path) && File.executable?(path)
    puts "  ✅ FOUND: #{path}"
    chromedriver_found = path
    break
  else
    puts "  ❌ NOT FOUND: #{path}"
  end
end

puts "\n🔍 Environment Variables:"
puts "  CHROME_BIN: #{ENV['CHROME_BIN'] || 'NOT SET'}"
puts "  CHROMEDRIVER_PATH: #{ENV['CHROMEDRIVER_PATH'] || 'NOT SET'}"

puts "\n🔍 System Info:"
puts "  Platform: #{RUBY_PLATFORM}"
puts "  Architecture: #{`uname -m`.strip rescue 'unknown'}"
puts "  OS: #{`uname -s`.strip rescue 'unknown'}"

# Test URLs that are known to work
test_urls = [
  {
    name: "Simple GoFood URL (should work)",
    url: "https://gofood.link/a/QK8wyTj"
  },
  {
    name: "Alternative GoFood URL",
    url: "https://gofood.link/a/PTGZGz7"
  }
]

if chrome_found && chromedriver_found
  puts "\n🚀 TESTING WITH FOUND BINARIES:"
  puts "Chrome: #{chrome_found}"
  puts "ChromeDriver: #{chromedriver_found}"
  puts "-" * 60

  ENV['CHROME_BIN'] = chrome_found
  ENV['CHROMEDRIVER_PATH'] = chromedriver_found

  test_urls.each_with_index do |test_case, i|
    puts "\n#{i + 1}/#{test_urls.length} - #{test_case[:name]}"
    puts "URL: #{test_case[:url]}"
    puts "-" * 40

    start_time = Time.now
    begin
      parser = GojekParserService.new
      result = parser.parse(test_case[:url])
      duration = Time.now - start_time

      if result
        puts "✅ SUCCESS (#{duration.round(2)}s)"
        puts "   🏪 Name: #{result[:name] || 'N/A'}"
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
      puts "   Backtrace (first 5 lines):"
      e.backtrace.first(5).each { |line| puts "     #{line}" }
    end
  end
else
  puts "\n❌ CANNOT TEST - Missing binaries:"
  puts "  Chrome: #{chrome_found ? '✅' : '❌'}"
  puts "  ChromeDriver: #{chromedriver_found ? '✅' : '❌'}"
end

puts "\n" + "=" * 60
puts "🔧 DIAGNOSIS COMPLETE"

# Production recommendations
puts "\n📋 PRODUCTION SETUP RECOMMENDATIONS:"
puts "-" * 40

if RUBY_PLATFORM.include?("linux")
  puts "For Linux Production Server:"
  puts "  1. Install Chromium: apt-get install chromium-browser"
  puts "  2. Install ChromeDriver: apt-get install chromium-chromedriver"
  puts "  3. Set ENV vars:"
  puts "     export CHROME_BIN=/usr/bin/chromium-browser"
  puts "     export CHROMEDRIVER_PATH=/usr/bin/chromedriver"
elsif RUBY_PLATFORM.include?("darwin")
  puts "For Mac Development:"
  puts "  1. Install Chrome: Download from Google"
  puts "  2. Install ChromeDriver: brew install chromedriver"
  puts "  3. Set ENV vars:"
  puts "     export CHROME_BIN='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'"
  puts "     export CHROMEDRIVER_PATH=/opt/homebrew/bin/chromedriver"
end

puts "\n🚀 Add to your deployment script:"
puts "export CHROME_BIN=<path_to_chrome>"
puts "export CHROMEDRIVER_PATH=<path_to_chromedriver>"
puts "bundle exec rails server"
