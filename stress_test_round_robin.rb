#!/usr/bin/env ruby

require_relative "config/environment"

puts "=== STRESS TEST: Round-Robin Restaurant Status Checks ==="
puts "Date: #{Time.current}"
puts "Method: 50 rounds, checking ALL restaurants in each round"
puts ""

restaurants = Restaurant.all
puts "Found #{restaurants.count} restaurants to test"
puts "Total rounds: 50"
puts "Total checks planned: #{restaurants.count * 50}"
puts ""

# Initialize results tracking
results = {}
restaurants.each do |restaurant|
  results[restaurant.id] = {
    name: restaurant.name,
    platform: restaurant.platform,
    url: restaurant.platform_url,
    checks_completed: 0,
    results: { open: 0, closed: 0, error: 0, unknown: 0 },
    errors: { waf_blocked: 0, timeout: 0, session_error: 0, other: 0 },
    response_times: []
  }
end

overall_stats = {
  total_checks: 0,
  successful: 0,
  errors: 0,
  waf_blocked: 0,
  timeouts: 0
}

# Main testing loop - 50 rounds
50.times do |round|
  puts "=" * 80
  puts "🔄 ROUND #{round + 1}/50"
  puts "=" * 80
  
  restaurants.each_with_index do |restaurant, restaurant_index|
    print "#{restaurant_index + 1}/#{restaurants.count}: #{restaurant.name[0..40]}... "
    
    start_time = Time.current
    restaurant_stats = results[restaurant.id]
    
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
          puts "🚫 WAF (#{duration.round(2)}s)"
        when /timeout/
          restaurant_stats[:errors][:timeout] += 1
          overall_stats[:timeouts] += 1
          puts "⏰ Timeout (#{duration.round(2)}s)"
        when /session/
          restaurant_stats[:errors][:session_error] += 1
          puts "🔧 Session (#{duration.round(2)}s)"
        else
          restaurant_stats[:errors][:other] += 1
          puts "❌ #{error_msg[0..30]} (#{duration.round(2)}s)"
        end
      end
      
      restaurant_stats[:checks_completed] += 1
      overall_stats[:total_checks] += 1
      
    rescue => e
      duration = Time.current - start_time
      restaurant_stats[:results][:error] += 1
      restaurant_stats[:errors][:other] += 1
      overall_stats[:errors] += 1
      overall_stats[:total_checks] += 1
      puts "💥 Exception: #{e.message[0..30]} (#{duration.round(2)}s)"
    end
    
    # Small delay between restaurants
    sleep(0.3)
  end
  
  # Round summary
  round_success = restaurants.map { |r| results[r.id][:checks_completed] }.sum
  round_errors = overall_stats[:errors]
  success_rate = round_success > 0 ? (overall_stats[:successful].to_f / overall_stats[:total_checks] * 100).round(1) : 0
  
  puts ""
  puts "📊 Round #{round + 1} Summary: #{overall_stats[:successful]}/#{overall_stats[:total_checks]} successful (#{success_rate}%)"
  puts "   WAF blocked: #{overall_stats[:waf_blocked]}, Timeouts: #{overall_stats[:timeouts]}"
  puts ""
  
  # Longer delay between rounds
  sleep(1)
end

puts "=" * 80
puts "🎯 FINAL STRESS TEST RESULTS"
puts "=" * 80
puts "Rounds completed: 50"
puts "Total restaurants: #{restaurants.count}"
puts "Total checks performed: #{overall_stats[:total_checks]}"
puts "Successful checks: #{overall_stats[:successful]}"
puts "Failed checks: #{overall_stats[:errors]}"
puts ""

if overall_stats[:total_checks] > 0
  success_rate = (overall_stats[:successful].to_f / overall_stats[:total_checks] * 100).round(1)
  waf_rate = (overall_stats[:waf_blocked].to_f / overall_stats[:total_checks] * 100).round(1)
  timeout_rate = (overall_stats[:timeouts].to_f / overall_stats[:total_checks] * 100).round(1)
  
  puts "📈 Overall Success Rate: #{success_rate}%"
  puts "🚫 WAF Block Rate: #{waf_rate}%"  
  puts "⏰ Timeout Rate: #{timeout_rate}%"
end

puts ""
puts "=" * 80
puts "📋 DETAILED RESULTS PER RESTAURANT"
puts "=" * 80

results.each do |restaurant_id, stats|
  success_count = stats[:results][:open] + stats[:results][:closed]
  success_rate = stats[:checks_completed] > 0 ? (success_count.to_f / stats[:checks_completed] * 100).round(1) : 0
  avg_response_time = stats[:response_times].empty? ? 0 : (stats[:response_times].sum / stats[:response_times].count).round(2)
  
  puts ""
  puts "🏪 #{stats[:name]} (#{stats[:platform]})"
  puts "   Checks completed: #{stats[:checks_completed]}/50"
  puts "   Success rate: #{success_rate}% (#{success_count}/#{stats[:checks_completed]})"
  puts "   Results: Open=#{stats[:results][:open]}, Closed=#{stats[:results][:closed]}, Error=#{stats[:results][:error]}"
  puts "   Error breakdown: WAF=#{stats[:errors][:waf_blocked]}, Timeout=#{stats[:errors][:timeout]}, Session=#{stats[:errors][:session_error]}, Other=#{stats[:errors][:other]}"
  puts "   Average response time: #{avg_response_time}s"
  puts "   URL: #{stats[:url]}"
end

puts ""
puts "🏁 Round-robin stress test completed at #{Time.current}"
puts "💡 Results show performance across #{restaurants.count} restaurants over 50 rounds"