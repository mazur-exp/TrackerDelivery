require 'nokogiri'
require 'json'

doc = Nokogiri::HTML(File.read('grab_with_auth_cookies.html'))
script = doc.css('script#__NEXT_DATA__').first

if script
  data = JSON.parse(script.text)
  redux = data.dig('props', 'initialReduxState', 'pageRestaurantDetail', 'entities')
  
  if redux && !redux.empty?
    puts "✅ ENTITIES POPULATED!"
    redux.each do |type, items|
      puts "\n#{type}: #{items.length} items"
      first = items.values.first
      if first
        puts "  Keys: #{first.keys.first(20)}"
        puts "  Name: #{first['name']}" if first['name']
        puts "  Rating: #{first['rating']}" if first['rating']
        puts "  OpeningHours: #{first['openingHours']}" if first['openingHours']
      end
    end
  else
    puts "❌ Entities still empty"
    puts "Redux state: #{data.dig('props', 'initialReduxState', 'pageRestaurantDetail').keys}"
  end
else
  puts "No __NEXT_DATA__"
end
