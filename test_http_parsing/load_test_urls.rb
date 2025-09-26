#!/usr/bin/env ruby

require_relative 'performance_comparison'

class TestUrlLoader
  def self.load_urls_from_file(filename = 'test_urls.txt')
    urls = []
    
    unless File.exist?(filename)
      puts "Error: #{filename} not found!"
      return urls
    end
    
    File.readlines(filename).each_with_index do |line, index|
      line = line.strip
      
      # Skip empty lines and comments
      next if line.empty? || line.start_with?('#')
      
      # Parse format: platform,url
      parts = line.split(',', 2)
      if parts.length != 2
        puts "Warning: Invalid format on line #{index + 1}: #{line}"
        next
      end
      
      platform = parts[0].strip.downcase
      url = parts[1].strip
      
      unless ['grab', 'gojek'].include?(platform)
        puts "Warning: Unknown platform '#{platform}' on line #{index + 1}"
        next
      end
      
      urls << { platform: platform, url: url }
    end
    
    puts "Loaded #{urls.length} test URLs"
    urls
  end
  
  def self.run_tests
    urls = load_urls_from_file
    
    if urls.empty?
      puts "\nNo valid URLs found in test_urls.txt"
      puts "Please add real restaurant URLs in format: platform,url"
      puts "\nExample:"
      puts "grab,https://food.grab.com/id/en/restaurant/example/IDGFTI123"
      puts "gojek,https://gofood.gojek.com/jakarta/restaurant/example-123"
      return
    end
    
    puts "Starting performance comparison with #{urls.length} URLs..."
    comparison = PerformanceComparison.new
    comparison.run_comparison(urls)
  end
end

# Run tests if called directly
if __FILE__ == $0
  TestUrlLoader.run_tests
end