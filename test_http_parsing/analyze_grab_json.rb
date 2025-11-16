require 'nokogiri'
require 'json'

doc = Nokogiri::HTML(File.read('grab_full_page.html'))
script = doc.css('script#__NEXT_DATA__').first

if script
  data = JSON.parse(script.text)
  redux = data.dig('props', 'initialReduxState', 'pageRestaurantDetail')
  
  if redux && redux['entities']
    puts "=== Entities Structure ===" 
    redux['entities'].each do |type, items|
      puts "\n#{type}: #{items.length} items"
      first = items.values.first
      puts "  Sample keys: #{first.keys.first(20)}" if first
    end
  end
end
