#!/usr/bin/env ruby

require_relative "config/environment"

puts "=== STRESS TEST: Restaurant Status Checks ==="
puts "Date: #{Time.current}"
puts "Testing: 50 checks per restaurant"
puts ""

restaurants = Restaurant.all
puts "Found #{restaurants.count} restaurants to test"
puts "Total checks planned: #{restaurants.count * 50}"
puts ""

results = {}
overall_stats = {
  total_checks: 0,
  successful: 0,
  errors: 0,
  waf_blocked: 0,
  timeouts: 0,
  unknown: 0
}

restaurants.each_with_index do |restaurant, restaurant_index|
  puts "=" * 80
  puts "#{restaurant_index + 1}/#{restaurants.count}: #{restaurant.name} (#{restaurant.platform})"
  puts "URL: #{restaurant.platform_url}"
  puts "=" * 80
  
  restaurant_stats = {
    name: restaurant.name,
    platform: restaurant.platform,
    url: restaurant.platform_url,
    checks_completed: 0,
    results: {
      open: 0,
      closed: 0,
      error: 0,
      unknown: 0
    },
    errors: {
      waf_blocked: 0,
      timeout: 0,
      session_error: 0,
      other: 0
    },
    response_times: []
  }
  
  50.times do |check_index|
    print "Check #{check_index + 1}/50: "
    
    start_time = Time.current
    
    begin
      case restaurant.platform
      when "grab"
        status_data = GrabParserService.new.check_status_only(restaurant.platform_url)
      when "gojek"
        status_data = GojekParserService.new.check_status_only(restaurant.platform_url)
      else
        status_data = { error: "Unknown platform: #{restaurant.platform}" }
      end
      
      duration = Time.current - start_time
      restaurant_stats[:response_times] << duration.round(2)
      
      if status_data && status_data[:error].nil?
        actual_status = status_data[:is_open] ? "open" : "closed"
        restaurant_stats[:results][actual_status.to_sym] += 1
        overall_stats[:successful] += 1
        puts "✅ #{actual_status} (#{duration.round(2)}s)"
      else
        error_msg = status_data&.dig(:error) || "Unknown error"
        restaurant_stats[:results][:error] += 1
        overall_stats[:errors] += 1
        
        # Categorize errors
        case error_msg.downcase
        when /waf/
          restaurant_stats[:errors][:waf_blocked] += 1
          overall_stats[:waf_blocked] += 1
          puts "🚫 WAF blocked (#{duration.round(2)}s)"
        when /timeout/
          restaurant_stats[:errors][:timeout] += 1
          overall_stats[:timeouts] += 1
          puts "⏰ Timeout (#{duration.round(2)}s)"
        when /session/
          restaurant_stats[:errors][:session_error] += 1
          puts "🔧 Session error (#{duration.round(2)}s)"
        else
          restaurant_stats[:errors][:other] += 1
          puts "❌ Error: #{error_msg} (#{duration.round(2)}s)"
        end
      end
      
      restaurant_stats[:checks_completed] += 1
      overall_stats[:total_checks] += 1
      
      # Small delay to avoid overwhelming servers
      sleep(0.5)
      
    rescue => e
      duration = Time.current - start_time
      restaurant_stats[:results][:error] += 1
      restaurant_stats[:errors][:other] += 1
      overall_stats[:errors] += 1
      overall_stats[:total_checks] += 1
      puts "💥 Exception: #{e.message} (#{duration.round(2)}s)"
      
      # Longer delay after exceptions
      sleep(1)
    end
  end
  
  # Calculate restaurant statistics
  avg_response_time = restaurant_stats[:response_times].empty? ? 0 : (restaurant_stats[:response_times].sum / restaurant_stats[:response_times].count).round(2)
  success_rate = ((restaurant_stats[:results][:open] + restaurant_stats[:results][:closed]).to_f / restaurant_stats[:checks_completed] * 100).round(1)
  
  puts ""
  puts "📊 Restaurant Summary:"
  puts "   Completed: #{restaurant_stats[:checks_completed]}/50"
  puts "   Success rate: #{success_rate}%"
  puts "   Avg response time: #{avg_response_time}s"
  puts "   Results: Open=#{restaurant_stats[:results][:open]}, Closed=#{restaurant_stats[:results][:closed]}, Error=#{restaurant_stats[:results][:error]}"
  puts "   Errors: WAF=#{restaurant_stats[:errors][:waf_blocked]}, Timeout=#{restaurant_stats[:errors][:timeout]}, Session=#{restaurant_stats[:errors][:session_error]}, Other=#{restaurant_stats[:errors][:other]}"
  puts ""
  
  results[restaurant.id] = restaurant_stats
end

puts "=" * 80
puts "🎯 OVERALL STRESS TEST RESULTS"
puts "=" * 80
puts "Total restaurants tested: #{restaurants.count}"
puts "Total checks performed: #{overall_stats[:total_checks]}"
puts "Successful checks: #{overall_stats[:successful]}"
puts "Failed checks: #{overall_stats[:errors]}"
puts ""

if overall_stats[:total_checks] > 0
  success_rate = (overall_stats[:successful].to_f / overall_stats[:total_checks] * 100).round(1)
  waf_rate = (overall_stats[:waf_blocked].to_f / overall_stats[:total_checks] * 100).round(1)
  timeout_rate = (overall_stats[:timeouts].to_f / overall_stats[:total_checks] * 100).round(1)
  
  puts "📈 Success Rate: #{success_rate}%"
  puts "🚫 WAF Block Rate: #{waf_rate}%"
  puts "⏰ Timeout Rate: #{timeout_rate}%"
end

puts ""
puts "=" * 80
puts "📋 DETAILED RESULTS PER RESTAURANT"
puts "=" * 80

results.each do |restaurant_id, stats|
  success_rate = ((stats[:results][:open] + stats[:results][:closed]).to_f / stats[:checks_completed] * 100).round(1)
  avg_response_time = stats[:response_times].empty? ? 0 : (stats[:response_times].sum / stats[:response_times].count).round(2)
  
  puts ""
  puts "🏪 #{stats[:name]} (#{stats[:platform]})"
  puts "   URL: #{stats[:url]}"
  puts "   Success: #{success_rate}% (#{stats[:results][:open] + stats[:results][:closed]}/#{stats[:checks_completed]})"
  puts "   Results: Open=#{stats[:results][:open]}, Closed=#{stats[:results][:closed]}, Error=#{stats[:results][:error]}"
  puts "   Errors: WAF=#{stats[:errors][:waf_blocked]}, Timeout=#{stats[:errors][:timeout]}, Session=#{stats[:errors][:session_error]}, Other=#{stats[:errors][:other]}"
  puts "   Avg response time: #{avg_response_time}s"
end

puts ""
puts "🏁 Stress test completed at #{Time.current}"