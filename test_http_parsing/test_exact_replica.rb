require 'httparty'
require 'json'

api_url = 'https://portal.grab.com/foodweb/guest/v2/merchants/6-C65ZV62KVNEDPE'
jwt = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnYWEiLCJhdWQiOiJnZnciLCJuYW1lIjoiZ3JhYnRheGkiLCJpYXQiOjE3NjMwOTcxNTUsImV4cCI6MTc2MzA5Nzc1NSwibmJmIjoxNjMwOTcxNTUsInZlciI6IjEuMTkuMC4yNCIsImJySUQiOiI4ZjU5NzRhMWFiMDJlMjBmYzJlNDJkYjdmNDY3ZjdlNmI1M3k2ciIsInN1cyI6ZmFsc2UsImJySUR2MiI6IjVjYmNlMjMwODMyYWEyYTUwYzY5ZDljYTJkZTI1NGNjNDdjeTZyIiwiYnJVSUQiOiI5YzY5NmZhYy04M2NjLTQyNmYtODIzYy1mMmRmYmQzZjdiYTAifQ.oEeoJ4Y6siFPsPK61lLlXFD-3m6Ef6bKWwpv1LOL6tcsBrwOiLdXcFvKzPkD_IxFwHxIq6mqcJaAVQREcKG9cYC-3jhgXQuEVLfZZDQ-aJunlPmkO5PlsPlqY8LrI4rfq4uiVhSkAZVIjq5M5NvZTuakj2L4vmGKIbbjYSjj_F_FW9JoFg3sqc_RRBd2T9jGzESECuPxcTsIUwEp35bfuiz2cin2akyfis2A1fGYKYrS3eDzISbecA0Y0rtlC0wZOw36MFsTTmPhhMSBS2dajK0rptlBUoNQ23RNJSSUKY6QCOpz662GD78mpS_TnoCm6W9Wd6-TGyY0mJZooVfBWQ'

# ПОЛНАЯ копия cookies из успешного браузерного запроса
cookies = '_gcl_au=1.1.1753922282.1762843336; _fbp=fb.1.1762843337865.786047362415167255; _hjSessionUser_1532049=eyJpZCI6IjJiOWZjMmFkLTY0YzItNTY5Yi04YzQzLTQwZGMwZGI4YjRlMyIsImNyZWF0ZWQiOjE3NjI4NDMzMzU5OTIsImV4aXN0aW5nIjp0cnVlfQ==; _gid=GA1.2.2030405715.1763092711; passenger_authn_token_jti=11245401-b55a-47e4-b994-2e6959a2d72c; passenger_authn_token=eyJhbGciOiJSUzI1NiIsImtpZCI6Il9kZWZhdWx0IiwidHlwIjoiSldUIn0.eyJhbXIiOiJXRUJMT0dJTiIsImF1ZCI6IlNTT19UT0tFTl9JU1NVSU5HX1NFUlZJQ0UiLCJleHAiOjE3NjU2ODQ3MTIsImdyb3VwIjoiR1VFU1QiLCJpYXQiOjE3NjMwOTI3MDksImp0aSI6IjExMjQ1NDAxLWI1NWEtNDdlNC1iOTk0LTJlNjk1OWEyZDcyYyIsInN1YiI6IkcwMS1LMlZxVEZOeVRGSldibFk0VG1GWmVWbDFTa3BhUVQwOSIsInN2YyI6IlBBU1NFTkdFUiJ9.F7ItXqPAQZfT61Rk-NdOBP0GQUtQpK9kqBlipjCPaefwLhQ-bUod7Do7xZbsJ_vdx1NfUw6mek2GRgozPcPYRfQzpDOOiT8xn7ixlR_LkSYaIZiXxYh0Ir5Ye5I8SbXKqKthj6A66CwH2Xs6-gXbv0BPsqjiJwgRE6HD6ulf7lMrEaSp3DrbltT2P6mbqR3nKF1P3J4s-pTp9gQ9z99bP7cCXqgak3T6Pm1ee1N5RKnsaNCq4TDeN8F79SUZ7A0ZYYhG7szo4QE7B6-jthsNgDFMtj7gRgpGosUOgUVrbCr_YHf2oH6QqBnnolxsT7Nrapy0ZsaNgBjARnv3fg7FKQ; _gat_UA-73060858-24=1; _hjSession_1532049=eyJpZCI6ImEzNTAxZTcxLWI4OTctNGUxMC1hMDA3LTJiOGU3ZmQ4MjU2ZSIsImMiOjE3NjMwOTYyMDEzNzksInMiOjAsInIiOjAsInNiIjowLCJzciI6MCwic2UiOjAsImZzIjowLCJzcCI6MH0=; _ga_RPEHNJMMEM=GS2.1.s1763096201$o3$g1$t1763096216$j45$l0$h1899076339; _ga=GA1.2.1452396840.1762843337'

response = HTTParty.get(api_url,
  query: { latlng: '-6.1767352,106.826504' },
  headers: {
    'accept' => 'application/json, text/plain, */*',
    'accept-language' => 'en',
    'cookie' => cookies,
    'origin' => 'https://food.grab.com',
    'referer' => 'https://food.grab.com/',
    'sec-ch-ua' => '"Chromium";v="142", "Google Chrome";v="142", "Not_A Brand";v="99"',
    'sec-ch-ua-mobile' => '?0',
    'sec-ch-ua-platform' => '"macOS"',
    'sec-fetch-dest' => 'empty',
    'sec-fetch-mode' => 'cors',
    'sec-fetch-site' => 'same-site',
    'user-agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    'x-country-code' => 'ID',
    'x-gfc-country' => 'ID',
    'x-grab-web-app-version' => 'uaf6yDMWlVv0CaTK5fHdB',
    'x-hydra-jwt' => jwt
  }
)

puts "Status: #{response.code}"

if response.code == 200
  data = JSON.parse(response.body)
  merchant = data['merchant']
  
  puts "\n🎉 УСПЕХ!"
  puts "Name: #{merchant['name']}"
  puts "Rating: #{merchant['rating']}"
  puts "Cuisine: #{merchant['cuisine']}"
  puts "Opening Hours (open): #{merchant['openingHours']['open']}"
  puts "Opening Hours (today): #{merchant['openingHours']['displayedHours']}"
else
  puts "Failed: #{response.code} - #{response.message}"
end
