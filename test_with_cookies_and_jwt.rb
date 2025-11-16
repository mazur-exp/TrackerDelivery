require 'httparty'
require 'json'

api_url = 'https://portal.grab.com/foodweb/guest/v2/merchants/6-C65ZV62KVNEDPE'

# JWT из ваших headers
hydra_jwt = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnYWEiLCJhdWQiOiJnZnciLCJuYW1lIjoiZ3JhYnRheGkiLCJpYXQiOjE3NjMwOTYyMDEsImV4cCI6MTc2MzA5NjgwMSwibmJmIjoxNzYzMDk2MjAxLCJ2ZXIiOiIxLjE5LjAuMjQiLCJicklEIjoiOGY1OTc0YTFhYjAyZTIwZmMyZTQyZGI3ZjQ2N2Y3ZTZiNTN5NnIiLCJzdXMiOmZhbHNlLCJicklEdjIiOiI1Y2JjZTIzMDgzMmFhMmE1MGM2OWQ5Y2EyZGUyNTRjYzQ3Y3k2ciIsImJyVUlEIjoiOWM2OTZmYWMtODNjYy00MjZmLTgyM2MtZjJkZmJkM2Y3YmEwIn0.Q50msejoBc6mZ7HoYoF8MiCS9R-jKAZxABZct7jSz-InYdkp5IwzzAeBQydnKhN9-jmrkdchbYxxLd6ki07ccr9jaoxPKfZM4z_GZgZi2RGD237xNasGhKFKM2zJ4kttWz9FwOcAgUIjCQrlaoKtt_Y3PtPzAOSNEkWrPMetIk6-IWy7dir707sBgNKW5cyuYzHyj9VFDPH9ArsZ4UCcjawhSivdqFwBR9WyEIGxX5OqQZj0glXiXrQbY_nDPib8iYFaFVSzY8d7AlRk3yZNE_W_54ZSLi7FkNLu1Xy2sBId5inJvNTBogy0EPZQ-XJau4cYcxrGSewNLE5r50jMFA'

# Cookies из вашего запроса (сокращённые - только важные)
cookie_string = 'passenger_authn_token_jti=11245401-b55a-47e4-b994-2e6959a2d72c; passenger_authn_token=eyJhbGciOiJSUzI1NiIsImtpZCI6Il9kZWZhdWx0IiwidHlwIjoiSldUIn0.eyJhbXIiOiJXRUJMT0dJTiIsImF1ZCI6IlNTT19UT0tFTl9JU1NVSU5HX1NFUlZJQ0UiLCJleHAiOjE3NjU2ODQ3MTIsImdyb3VwIjoiR1VFU1QiLCJpYXQiOjE3NjMwOTI3MDksImp0aSI6IjExMjQ1NDAxLWI1NWEtNDdlNC1iOTk0LTJlNjk1OWEyZDcyYyIsInN1YiI6IkcwMS1LMlZxVEZOeVRGSldibFk0VG1GWmVWbDFTa3BhUVQwOSIsInN2YyI6IlBBU1NFTkdFUiJ9.F7ItXqPAQZfT61Rk-NdOBP0GQUtQpK9kqBlipjCPaefwLhQ-bUod7Do7xZbsJ_vdx1NfUw6mek2GRgozPcPYRfQzpDOOiT8xn7ixlR_LkSYaIZiXxYh0Ir5Ye5I8SbXKqKthj6A66CwH2Xs6-gXbv0BPsqjiJwgRE6HD6ulf7lMrEaSp3DrbltT2P6mbqR3nKF1P3J4s-pTp9gQ9z99bP7cCXqgak3T6Pm1ee1N5RKnsaNCq4TDeN8F79SUZ7A0ZYYhG7szo4QE7B6-jthsNgDFMtj7gRgpGosUOgUVrbCr_YHf2oH6QqBnnolxsT7Nrapy0ZsaNgBjARnv3fg7FKQ'

response = HTTParty.get(api_url,
  query: { latlng: '-6.1767352,106.826504' },
  headers: {
    'Accept' => 'application/json, text/plain, */*',
    'accept-language' => 'en',
    'Cookie' => cookie_string,
    'x-hydra-jwt' => hydra_jwt,
    'x-country-code' => 'ID',
    'x-gfc-country' => 'ID',
    'x-grab-web-app-version' => 'uaf6yDMWlVv0CaTK5fHdB',
    'Referer' => 'https://food.grab.com/',
    'Origin' => 'https://food.grab.com',
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    'sec-fetch-dest' => 'empty',
    'sec-fetch-mode' => 'cors',
    'sec-fetch-site' => 'same-site'
  }
)

puts "Status: #{response.code}"

if response.code == 200
  data = JSON.parse(response.body)
  merchant = data['merchant']
  
  puts "\n🎉 SUCCESS!"
  puts "\nBasic Info:"
  puts "  Name: #{merchant['name']}"
  puts "  Rating: #{merchant['rating']}"
  puts "  Cuisine: #{merchant['cuisine']}"
  puts "  Distance: #{merchant['distanceInKm']} km"
  
  puts "\nOpening Hours:"
  merchant['openingHours'].each { |k,v| puts "  #{k}: #{v}" }
  
  puts "\nCoordinates: #{merchant['latlng']}"
  puts "Photo: #{merchant['photoHref']}"
  
  File.write('grab_api_success.json', JSON.pretty_generate(data))
  puts "\n✅ Full response saved!"
else
  puts "\n❌ Failed: #{response.code}"
  puts response.body[0..200] if response.body
end
