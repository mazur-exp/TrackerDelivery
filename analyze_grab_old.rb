require 'nokogiri'
require 'json'

doc = Nokogiri::HTML(File.read('grab_page.html'))
script = doc.css('script#__NEXT_DATA__').first

if script
  data = JSON.parse(script.text)
  
  puts "=== OLD grab_page.html Analysis ==="
  puts "File size: #{File.size('grab_page.html')} bytes"
  
  redux = data.dig('props', 'initialReduxState', 'pageRestaurantDetail')
  if redux
    puts "\npageRestaurantDetail.entities:"
    if redux['entities'] && !redux['entities'].empty?
      redux['entities'].each do |type, items|
        puts "  #{type}: #{items.length} items"
        
        if items.length > 0
          first_key = items.keys.first
          first_item = items[first_key]
          
          puts "    First item keys: #{first_item.keys.first(25)}"
          puts "    Name: #{first_item['name']}" if first_item['name']
          puts "    Rating: #{first_item['rating']}" if first_item['rating']
          puts "    Cuisine: #{first_item['cuisine']}" if first_item['cuisine']
          puts "    OpeningHours: #{first_item['openingHours']}" if first_item['openingHours']
        end
      end
    else
      puts "  EMPTY entities: {}"
    end
  end
  
  # Проверяем другие возможные источники
  puts "\nChecking other data sources..."
  puts "ssrState keys: #{data.dig('props', 'ssrState')&.keys}"
  puts "pageProps keys: #{data.dig('props', 'pageProps')&.keys}"
  
end
