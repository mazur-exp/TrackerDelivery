require 'httparty'
require 'json'

response = HTTParty.get(
  'https://portal.grab.com/foodweb/guest/v2/merchants/6-C65ZV62KVNEDPE',
  query: { latlng: '-8.6705,115.2126' },
  headers: {
    'Accept' => 'application/json',
    'x-country-code' => 'ID',
    'Referer' => 'https://food.grab.com/',
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  }
)

puts "Status: #{response.code}"
puts "Body length: #{response.body.length}"
if response.success?
  data = JSON.parse(response.body)
  merchant = data['merchant']
  puts "\nName: #{merchant['name']}"
  puts "Rating: #{merchant['rating']}"
  puts "Cuisine: #{merchant['cuisine']}"
  puts "Opening Hours: #{merchant['openingHours']}"
else
  puts "Error: #{response.body}"
end
