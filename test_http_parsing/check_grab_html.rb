require 'httparty'

url = "https://r.grab.com/g/6-20250920_121514_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C65ZV62KVNEDPE"
response = HTTParty.get(url, follow_redirects: true)

puts "URL: #{response.request.last_uri}"
puts "Status: #{response.code}"
puts "HTML Length: #{response.body.length}"
puts "\nContains h1 tag: #{response.body.include?('<h1')}"
puts "Contains 'Healthy Fit': #{response.body.include?('Healthy Fit')}"
puts "Contains '__NEXT_DATA__': #{response.body.include?('__NEXT_DATA__')}"
puts "Contains 'Opening Hours': #{response.body.include?('Opening Hours')}"
puts "Contains rating: #{response.body.include?('4.7')}"

# Сохраним HTML для анализа
File.write('grab_test_response.html', response.body)
puts "\nHTML saved to: grab_test_response.html"
