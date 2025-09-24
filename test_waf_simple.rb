#!/usr/bin/env ruby

require_relative "config/environment"

puts "=== WAF Bypass Improvements - Summary ==="
puts "Date: #{Time.current}"
puts ""

# Check recent WAF errors
puts "🔍 Checking recent WAF blocking rates..."

recent_checks = RestaurantStatusCheck.where("checked_at > ?", 2.hours.ago)
total_checks = recent_checks.count
waf_errors = recent_checks.where("parser_response LIKE '%WAF%' OR parser_response LIKE '%waf%'").count

puts "📊 Last 2 hours statistics:"
puts "   Total checks: #{total_checks}"
puts "   WAF blocked: #{waf_errors}"

if total_checks > 0
  waf_rate = (waf_errors.to_f / total_checks * 100).round(1)
  puts "   WAF block rate: #{waf_rate}%"
  
  if waf_rate > 50
    puts "   Status: 🔴 High WAF blocking - improvements needed"
  elsif waf_rate > 20 
    puts "   Status: 🟡 Moderate WAF blocking - monitoring"
  else
    puts "   Status: 🟢 Low WAF blocking - improvements working"
  end
else
  puts "   Status: ⚪ No recent data available"
end

puts ""
puts "✅ Improvements Applied:"
puts "   ✓ User-Agent list expanded (5 → 22 variants)"
puts "   ✓ Chrome flags conflict fixed in GoJek"
puts "   ✓ Advanced anti-bot flags added"
puts "   ✓ Firefox, Safari, Edge, Mobile support added"

puts ""
puts "📈 Expected Results:"
puts "   • WAF blocking should decrease from ~70% to ~20-30%" 
puts "   • Better parsing success rate"
puts "   • Fewer 'Error' statuses in dashboard"
puts "   • More accurate restaurant status detection"

puts ""
puts "🎯 Next Steps:"
puts "   1. Monitor dashboard for reduced 'Error' statuses"
puts "   2. Check WAF blocking rates over next 30 minutes"
puts "   3. If still high, consider proxy rotation"