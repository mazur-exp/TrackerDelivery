require 'httparty'
require 'json'

api_url = 'https://portal.grab.com/foodweb/guest/v2/merchants/6-C65ZV62KVNEDPE'
hydra_jwt = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnYWEiLCJhdWQiOiJnZnciLCJuYW1lIjoiZ3JhYnRheGkiLCJpYXQiOjE3NjMwOTYyMDEsImV4cCI6MTc2MzA5NjgwMSwibmJmIjoxNzYzMDk2MjAxLCJ2ZXIiOiIxLjE5LjAuMjQiLCJicklEIjoiOGY1OTc0YTFhYjAyZTIwZmMyZTQyZGI3ZjQ2N2Y3ZTZiNTN5NnIiLCJzdXMiOmZhbHNlLCJicklEdjIiOiI1Y2JjZTIzMDgzMmFhMmE1MGM2OWQ5Y2EyZGUyNTRjYzQ3Y3k2ciIsImJyVUlEIjoiOWM2OTZmYWMtODNjYy00MjZmLTgyM2MtZjJkZmJkM2Y3YmEwIn0.Q50msejoBc6mZ7HoYoF8MiCS9R-jKAZxABZct7jSz-InYdkp5IwzzAeBQydnKhN9-jmrkdchbYxxLd6ki07ccr9jaoxPKfZM4z_GZgZi2RGD237xNasGhKFKM2zJ4kttWz9FwOcAgUIjCQrlaoKtt_Y3PtPzAOSNEkWrPMetIk6-IWy7dir707sBgNKW5cyuYzHyj9VFDPH9ArsZ4UCcjawhSivdqFwBR9WyEIGxX5OqQZj0glXiXrQbY_nDPib8iYFaFVSzY8d7AlRk3yZNE_W_54ZSLi7FkNLu1Xy2sBId5inJvNTBogy0EPZQ-XJau4cYcxrGSewNLE5r50jMFA'

response = HTTParty.get(api_url,
  query: { latlng: '-8.6705,115.2126' },
  headers: {
    'Accept' => 'application/json, text/plain, */*',
    'accept-language' => 'en',
    'x-hydra-jwt' => hydra_jwt,
    'x-country-code' => 'ID',
    'x-gfc-country' => 'ID',
    'x-grab-web-app-version' => 'uaf6yDMWlVv0CaTK5fHdB',
    'Referer' => 'https://food.grab.com/',
    'Origin' => 'https://food.grab.com',
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  }
)

puts "Status: #{response.code}"

if response.code == 200
  data = JSON.parse(response.body)
  merchant = data['merchant']
  
  puts "\n✅ SUCCESS!"
  puts "Name: #{merchant['name']}"
  puts "Rating: #{merchant['rating']}"
  puts "Cuisine: #{merchant['cuisine']}"
  puts "Opening Hours: #{merchant['openingHours']}"
  puts "Address: #{merchant['address']}"
  
  # Save full response
  File.write('grab_api_response.json', JSON.pretty_generate(data))
  puts "\nFull response saved to: grab_api_response.json"
else
  puts "Failed: #{response.body}"
end
