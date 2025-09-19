#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

class GoogleGeocodingTest
  def initialize
    @restaurant_lat = -8.637902
    @restaurant_lng = 115.157834
  end
  
  def reverse_geocode
    puts "🗺️  Google Maps Reverse Geocoding Test"
    puts "=" * 50
    puts "📍 Координаты ресторана: #{@restaurant_lat}, #{@restaurant_lng}"
    puts ""
    
    # Пробуем без API ключа (ограниченное использование)
    puts "🔍 Попытка 1: Без API ключа (публичный доступ)"
    result1 = try_without_api_key
    
    if result1
      puts "✅ Успешно получен адрес!"
      parse_and_display_result(result1)
    else
      puts "❌ Не удалось получить адрес без API ключа"
    end
    
    puts "\n" + "=" * 50
    puts "📝 Результат:"
    
    if result1
      puts "🎯 Адрес найден через Google Maps"
    else
      puts "❌ Требуется API ключ Google Maps для точного адреса"
      puts "💡 Альтернативы:"
      puts "   - Использовать 'Tibubeneng, Bali' из названия"
      puts "   - Использовать координаты напрямую"
      puts "   - Попробовать другие геокодинг сервисы"
    end
  end
  
  private
  
  def try_without_api_key
    begin
      # Google Maps Geocoding API endpoint
      base_url = "https://maps.googleapis.com/maps/api/geocode/json"
      params = "latlng=#{@restaurant_lat},#{@restaurant_lng}&sensor=false"
      
      uri = URI("#{base_url}?#{params}")
      
      puts "🌐 Запрос: #{uri}"
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
      
      response = http.request(request)
      
      puts "📡 HTTP статус: #{response.code}"
      
      if response.code == '200'
        data = JSON.parse(response.body)
        puts "📊 Ответ получен, статус: #{data['status']}"
        
        if data['status'] == 'OK' && data['results'] && data['results'].length > 0
          return data
        elsif data['status'] == 'REQUEST_DENIED'
          puts "🔒 Доступ запрещен - нужен API ключ"
          puts "💬 Сообщение: #{data['error_message']}" if data['error_message']
          return nil
        else
          puts "⚠️  Статус ответа: #{data['status']}"
          puts "💬 Сообщение: #{data['error_message']}" if data['error_message']
          return nil
        end
      else
        puts "❌ HTTP ошибка: #{response.code} #{response.message}"
        return nil
      end
      
    rescue => e
      puts "❌ Ошибка запроса: #{e.message}"
      return nil
    end
  end
  
  def parse_and_display_result(data)
    results = data['results']
    
    puts "🏠 Найдено адресов: #{results.length}"
    puts ""
    
    results.first(3).each_with_index do |result, index|
      puts "#{index + 1}. #{result['formatted_address']}"
      
      # Проверяем компоненты адреса
      components = result['address_components']
      address_details = {}
      
      components.each do |component|
        types = component['types']
        if types.include?('route')
          address_details[:street] = component['long_name']
        elsif types.include?('sublocality') || types.include?('sublocality_level_1')
          address_details[:area] = component['long_name'] 
        elsif types.include?('locality')
          address_details[:city] = component['long_name']
        elsif types.include?('administrative_area_level_1')
          address_details[:state] = component['long_name']
        elsif types.include?('country')
          address_details[:country] = component['long_name']
        end
      end
      
      if address_details.any?
        puts "   📋 Компоненты:"
        puts "      Улица: #{address_details[:street]}" if address_details[:street]
        puts "      Район: #{address_details[:area]}" if address_details[:area]
        puts "      Город: #{address_details[:city]}" if address_details[:city] 
        puts "      Штат: #{address_details[:state]}" if address_details[:state]
        puts "      Страна: #{address_details[:country]}" if address_details[:country]
      end
      
      # Проверяем содержит ли адрес "Padonan"
      formatted_address = result['formatted_address']
      if formatted_address.include?('Padonan')
        puts "   🎯 ОТЛИЧНО! Адрес содержит 'Padonan'"
      elsif formatted_address.include?('Jl.')
        puts "   ✅ Адрес содержит 'Jl.' (индонезийская улица)"
      end
      
      puts ""
    end
  end
end

# Запуск теста
tester = GoogleGeocodingTest.new
tester.reverse_geocode