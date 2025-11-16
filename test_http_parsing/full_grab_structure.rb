require 'nokogiri'
require 'json'

doc = Nokogiri::HTML(File.read('grab_full_page.html'))
script = doc.css('script#__NEXT_DATA__').first

if script
  data = JSON.parse(script.text)
  
  puts "=== Top level structure ==="
  puts "Keys: #{data.keys}"
  puts "\nProps keys: #{data['props'].keys}"
  
  redux = data.dig('props', 'initialReduxState')
  if redux
    puts "\ninitialReduxState keys: #{redux.keys}"
    
    pageDetail = redux['pageRestaurantDetail']
    if pageDetail
      puts "\npageRestaurantDetail keys: #{pageDetail.keys}"
      puts "  entities: #{pageDetail['entities']}"
      puts "  cuisine: #{pageDetail['cuisine']}"
    end
  end
  
  # Check if data is actually in the page somewhere else
  pageProps = data.dig('props', 'pageProps')
  if pageProps
    puts "\npageProps: #{pageProps.keys}"
    puts "  query: #{pageProps['query']}"
  end
end
