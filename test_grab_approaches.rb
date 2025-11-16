require 'httparty'
require 'http-cookie'
require 'json'

# Load cookies
cookies_data = JSON.parse(File.read('grab_cookies.json'))
cookie_jar = HTTP::CookieJar.new
uri = URI.parse('https://food.grab.com/')
cookies_data['cookies'].each { |n,v| cookie_jar.add(HTTP::Cookie.new(name: n, value: v, domain: 'food.grab.com', path: '/')) }
cookie_header = cookie_jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join('; ')

merchant_id = "6-C65ZV62KVNEDPE"
api_url = "https://portal.grab.com/foodweb/guest/v2/merchants/#{merchant_id}"

puts "=== Testing Different API Approaches ===\n"

# Approach 1: With cookies only
puts "1. API with cookies only:"
r1 = HTTParty.get(api_url, 
  query: { latlng: '-8.6705,115.2126' },
  headers: { 'Cookie' => cookie_header, 'Accept' => 'application/json', 'x-country-code' => 'ID' }
)
puts "   Status: #{r1.code}"

# Approach 2: With apiKeyBrowser
puts "\n2. API with x-api-key header:"
r2 = HTTParty.get(api_url,
  query: { latlng: '-8.6705,115.2126' },
  headers: {
    'Cookie' => cookie_header,
    'Accept' => 'application/json',
    'x-api-key' => 'adf97b9132e1476eba170c84848c93ed',
    'x-country-code' => 'ID'
  }
)
puts "   Status: #{r2.code}"

# Approach 3: With Authorization header
puts "\n3. API with Authorization Bearer:"
r3 = HTTParty.get(api_url,
  query: { latlng: '-8.6705,115.2126' },
  headers: {
    'Cookie' => cookie_header,
    'Accept' => 'application/json',
    'Authorization' => 'Bearer adf97b9132e1476eba170c84848c93ed',
    'x-country-code' => 'ID'
  }
)
puts "   Status: #{r3.code}"

# Approach 4: Try passenger_authn_token_jti as auth
puts "\n4. API with passenger token:"
passenger_token = cookies_data['cookies']['passenger_authn_token_jti']
r4 = HTTParty.get(api_url,
  query: { latlng: '-8.6705,115.2126' },
  headers: {
    'Cookie' => cookie_header,
    'Accept' => 'application/json',
    'x-passenger-token' => passenger_token,
    'x-country-code' => 'ID'
  }
)
puts "   Status: #{r4.code}"

puts "\n=== Summary ==="
[r1, r2, r3, r4].each_with_index do |r, i|
  puts "Approach #{i+1}: #{r.code} - #{r.code == 200 ? 'SUCCESS!' : 'Failed'}"
end
