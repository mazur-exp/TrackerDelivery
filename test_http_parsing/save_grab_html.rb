require 'httparty'
require 'http-cookie'
require 'json'

cookies_data = JSON.parse(File.read('../grab_cookies.json'))
cookie_jar = HTTP::CookieJar.new
uri = URI.parse('https://food.grab.com/')
cookies_data['cookies'].each { |n,v| cookie_jar.add(HTTP::Cookie.new(name: n, value: v, domain: 'food.grab.com', path: '/')) }

url = "https://r.grab.com/g/6-20250920_121514_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C65ZV62KVNEDPE"
cookie_header = cookie_jar.cookies.map { |c| "#{c.name}=#{c.value}" }.join('; ')

response = HTTParty.get(url, follow_redirects: true, timeout: 10,
  headers: { 'Cookie' => cookie_header, 'User-Agent' => 'Mozilla/5.0', 'Accept' => 'text/html' })

File.write('grab_full_page.html', response.body)
puts "Saved: grab_full_page.html (#{response.body.length} bytes)"
