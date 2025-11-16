require 'httparty'
require 'http-cookie'
require 'json'

# Load cookies
cookies_data = JSON.parse(File.read('../grab_cookies.json'))
cookie_jar = HTTP::CookieJar.new

uri = URI.parse('https://food.grab.com/')
cookies_data['cookies'].each do |name, value|
  cookie = HTTP::Cookie.new(name: name, value: value, domain: 'food.grab.com', path: '/')
  cookie_jar.add(cookie)
end

puts "Loaded #{cookie_jar.cookies.length} cookies"

# Make request
url = "https://r.grab.com/g/6-20250920_121514_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C65ZV62KVNEDPE"
cookie_header = cookie_jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join('; ')

response = HTTParty.get(url, 
  follow_redirects: true,
  headers: {
    'Cookie' => cookie_header,
    'User-Agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Accept' => 'text/html'
  }
)

puts "Status: #{response.code}"
puts "Length: #{response.body.length}"
puts "Contains 'Healthy Fit': #{response.body.include?('Healthy Fit')}"
puts "Contains '__NEXT_DATA__': #{response.body.include?('__NEXT_DATA__')}"
