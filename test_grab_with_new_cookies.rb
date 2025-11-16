require 'httparty'

url = "https://food.grab.com/id/en/restaurant/healthy-fit-bowl-pasta-salad-wrap-bali-canggu-delivery/6-C65ZV62KVNEDPE"

# Cookies из вашего успешного запроса
cookie_string = 'gfc_country=ID; location=%7B%22latitude%22%3A-6.1767352%2C%22longitude%22%3A106.826504%2C%22address%22%3A%22Jakarta%22%2C%22countryCode%22%3A%22ID%22%2C%22isAccurate%22%3Afalse%2C%22addressDetail%22%3A%22%22%2C%22noteToDriver%22%3A%22%22%2C%22city%22%3A%22%22%2C%22cityID%22%3A0%2C%22displayAddress%22%3A%22%22%7D; next-i18next=en; passenger_authn_token_jti=11245401-b55a-47e4-b994-2e6959a2d72c; aws-waf-token=600e91fa-bb08-4bd6-8170-42d9a6990b04:GgoAZ90hDXc2AAAA:bENstpbwRRJnbc1+WYIydffFWu3ETINRR7PNE7Lgp2bInEs9avVpkdV2E+lzw77PGU38lUUxbsNPl/lO+gv58vQnRDfFRzwdVQaWJXJKTK+ZmeNI3JQx5pmC2o8nOUTg4asnMfHA2boHHKbW49fS6ptwj8JNAsU0Hwjl8mdyn3mOJVB1Az/z6EVZlZmkIaWXszx5L6jcfM0zyw01IpHvV/NAt5N3ZgoiuHDWMNJ3NPysdMa3c9FU6HZgyjP3qjqQcKGb0A=='

response = HTTParty.get(url,
  headers: {
    'Cookie' => cookie_string,
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36',
    'Accept' => 'text/html',
    'Referer' => 'https://food.grab.com/'
  }
)

puts "Status: #{response.code}"
puts "Length: #{response.body.length}"
puts "Has Healthy Fit: #{response.body.include?('Healthy Fit')}"
puts "Has __NEXT_DATA__: #{response.body.include?('__NEXT_DATA__')}"

# Save
File.write('grab_with_auth_cookies.html', response.body)
puts "\nSaved to: grab_with_auth_cookies.html"
