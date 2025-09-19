#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

# Test different approaches to access Grab mobile data
test_url = "https://r.grab.com/g/6-20250919_142036_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"

puts "Testing Grab mobile URL approaches:"
puts "=" * 80

# 1. Try direct HTTP request with mobile user agent
puts "\n1. Direct HTTP request with mobile user agent:"
begin
  uri = URI(test_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  
  request = Net::HTTP::Get.new(uri)
  request['User-Agent'] = 'GrabFood/4.58.0 (iPhone; iOS 17.0; Scale/3.00)'
  request['Accept'] = 'application/json, text/html'
  
  response = http.request(request)
  puts "Status: #{response.code}"
  puts "Redirect location: #{response['location']}" if response['location']
  puts "Content-Type: #{response['content-type']}"
  puts "Body preview: #{response.body[0..200]}..."
rescue => e
  puts "Error: #{e.message}"
end

# 2. Follow redirects manually
puts "\n2. Following redirects manually:"
current_url = test_url
redirects = 0
max_redirects = 5

while redirects < max_redirects
  begin
    uri = URI(current_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'GrabFood/4.58.0 (iPhone; iOS 17.0; Scale/3.00)'
    
    response = http.request(request)
    puts "Step #{redirects + 1}: #{current_url} -> Status: #{response.code}"
    
    if response.code.start_with?('3') && response['location']
      current_url = response['location']
      redirects += 1
    else
      puts "Final URL: #{current_url}"
      puts "Final status: #{response.code}"
      break
    end
  rescue => e
    puts "Error at step #{redirects + 1}: #{e.message}"
    break
  end
end

# 3. Try API endpoint extraction
puts "\n3. Checking if we can extract restaurant ID:"
if test_url.match(/6-([A-Z0-9]+)/)
  restaurant_id = $1
  puts "Extracted restaurant ID: #{restaurant_id}"
  
  # Try potential API endpoints
  api_urls = [
    "https://api.grab.com/grabfood/v1/restaurants/#{restaurant_id}",
    "https://portal.grab.com/foodweb/v2/restaurants/#{restaurant_id}",
    "https://food.grab.com/api/restaurants/#{restaurant_id}"
  ]
  
  api_urls.each do |api_url|
    begin
      uri = URI(api_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'GrabFood/4.58.0 (iPhone; iOS 17.0; Scale/3.00)'
      request['Accept'] = 'application/json'
      
      response = http.request(request)
      puts "API #{api_url}: Status #{response.code}"
    rescue => e
      puts "API #{api_url}: Error - #{e.message}"
    end
  end
end