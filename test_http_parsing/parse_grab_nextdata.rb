require 'httparty'
require 'http-cookie'
require 'json'
require 'nokogiri'

# Load cookies
cookies_data = JSON.parse(File.read('../grab_cookies.json'))
cookie_jar = HTTP::CookieJar.new

uri = URI.parse('https://food.grab.com/')
cookies_data['cookies'].each do |name, value|
  cookie = HTTP::Cookie.new(name: name, value: value, domain: 'food.grab.com', path: '/')
  cookie_jar.add(cookie)
end

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

# Parse HTML
doc = Nokogiri::HTML(response.body)
script = doc.css('script#__NEXT_DATA__').first

if script
  data = JSON.parse(script.text)
  
  # Ищем данные ресторана
  redux_state = data.dig('props', 'initialReduxState', 'pageRestaurantDetail')
  
  if redux_state && redux_state['entities']
    puts "Found entities with keys: #{redux_state['entities'].keys}"
    
    # Проверяем каждый entity type
    redux_state['entities'].each do |entity_type, entities|
      puts "\n#{entity_type}: #{entities.keys.first(3)}"
      
      # Показываем первый объект
      first_entity = entities.values.first
      if first_entity
        puts "  Keys: #{first_entity.keys.first(15)}"
        puts "  Name: #{first_entity['name']}" if first_entity['name']
        puts "  Rating: #{first_entity['rating']}" if first_entity['rating']
      end
    end
  else
    puts "No entities found"
    puts "Redux state keys: #{redux_state&.keys}"
  end
else
  puts "No __NEXT_DATA__ found"
end
