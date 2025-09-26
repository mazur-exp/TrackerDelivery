#!/usr/bin/env ruby

require_relative 'test_grab_http'
require_relative 'test_gojek_http'

class PerformanceComparison
  def initialize
    @grab_parser = TestGrabHttpParser.new
    @gojek_parser = TestGojekHttpParser.new
    @results = {
      grab: { success: 0, failed: 0, total_time: 0, data_quality: [] },
      gojek: { success: 0, failed: 0, total_time: 0, data_quality: [] }
    }
  end
  
  def run_comparison(test_urls)
    puts "=== HTTP Parsing Performance Comparison ==="
    puts "Testing #{test_urls.length} URLs\n"
    
    test_urls.each_with_index do |url_info, index|
      puts "\n--- Test #{index + 1}/#{test_urls.length} ---"
      
      platform = url_info[:platform]
      url = url_info[:url]
      
      case platform
      when 'grab'
        test_grab_url(url)
      when 'gojek'
        test_gojek_url(url)
      else
        puts "Unknown platform: #{platform}"
      end
      
      # Small delay between tests
      sleep(1)
    end
    
    display_summary
  end
  
  def test_grab_url(url)
    puts "Testing Grab URL..."
    result = @grab_parser.test_parse(url)
    
    if result[:success]
      @results[:grab][:success] += 1
      @results[:grab][:total_time] += result[:duration]
      
      quality_score = calculate_data_quality(result[:data])
      @results[:grab][:data_quality] << quality_score
      
      puts "✓ Success (#{result[:duration].round(2)}s, quality: #{quality_score}%)"
    else
      @results[:grab][:failed] += 1
      puts "✗ Failed: #{result[:error]}"
    end
  end
  
  def test_gojek_url(url)
    puts "Testing GoJek URL..."
    result = @gojek_parser.test_parse(url)
    
    if result[:success]
      @results[:gojek][:success] += 1
      @results[:gojek][:total_time] += result[:duration]
      
      quality_score = calculate_data_quality(result[:data])
      @results[:gojek][:data_quality] << quality_score
      
      puts "✓ Success (#{result[:duration].round(2)}s, quality: #{quality_score}%)"
    else
      @results[:gojek][:failed] += 1
      puts "✗ Failed: #{result[:error]}"
    end
  end
  
  def calculate_data_quality(data)
    return 0 if data.nil? || data.empty?
    
    # Score based on available data fields
    score = 0
    total_fields = 6
    
    score += 25 if data[:name] && !data[:name].empty?          # Name is most important
    score += 20 if data[:address] && !data[:address].empty?       # Address is very important  
    score += 15 if data[:rating] && !data[:rating].empty?        # Rating is important
    score += 15 if data[:cuisines]&.any?         # Cuisines are important
    score += 15 if data[:image_url] && !data[:image_url].empty?     # Image is nice to have
    score += 10 if data[:coordinates] && !data[:coordinates].empty?   # Coordinates are bonus
    
    score
  end
  
  def display_summary
    puts "\n" + "="*60
    puts "PERFORMANCE SUMMARY"
    puts "="*60
    
    [:grab, :gojek].each do |platform|
      stats = @results[platform]
      total_tests = stats[:success] + stats[:failed]
      
      next if total_tests == 0
      
      success_rate = (stats[:success].to_f / total_tests * 100).round(1)
      avg_time = stats[:success] > 0 ? (stats[:total_time] / stats[:success]).round(2) : 0
      avg_quality = stats[:data_quality].any? ? (stats[:data_quality].sum / stats[:data_quality].length).round(1) : 0
      
      puts "\n#{platform.upcase} Results:"
      puts "  Tests: #{total_tests} (#{stats[:success]} success, #{stats[:failed]} failed)"
      puts "  Success Rate: #{success_rate}%"
      puts "  Average Time: #{avg_time}s"
      puts "  Average Data Quality: #{avg_quality}%"
      puts "  Time Range: #{format_time_range(stats[:data_quality])}"
    end
    
    # Compare with typical Chrome performance
    puts "\n" + "-"*40
    puts "COMPARISON WITH CHROME PARSING:"
    puts "  Chrome typical time: 30-60s"
    puts "  HTTP typical time: 2-15s"
    puts "  Expected speedup: 2-30x faster"
    puts "-"*40
  end
  
  def format_time_range(quality_scores)
    return "N/A" if quality_scores.empty?
    "#{quality_scores.min}% - #{quality_scores.max}%"
  end
  
  def self.sample_test_urls
    [
      # Add real URLs here for testing
      # { platform: 'grab', url: 'https://food.grab.com/id/en/restaurant/...' },
      # { platform: 'gojek', url: 'https://www.gojek.com/gofood/restaurant/...' }
    ]
  end
end

# Usage
if __FILE__ == $0
  test_urls = PerformanceComparison.sample_test_urls
  
  if test_urls.empty?
    puts "No test URLs configured!"
    puts "Edit this file and add real restaurant URLs to test_urls array"
    puts "\nExample format:"
    puts "test_urls = ["
    puts "  { platform: 'grab', url: 'https://food.grab.com/id/en/restaurant/...' },"
    puts "  { platform: 'gojek', url: 'https://www.gojek.com/gofood/restaurant/...' }"
    puts "]"
  else
    comparison = PerformanceComparison.new
    comparison.run_comparison(test_urls)
  end
end