#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'

class FreeGeocodingTest
  def initialize
    @restaurant_lat = -8.637902
    @restaurant_lng = 115.157834
  end
  
  def test_all_services
    puts "🌍 Free Geocoding Services Test"
    puts "=" * 50
    puts "📍 Координаты: #{@restaurant_lat}, #{@restaurant_lng}"
    puts "🎯 Ищем: Jl. Raya Padonan или похожий адрес"
    puts ""
    
    services = [
      {
        name: "OpenStreetMap Nominatim",
        method: :test_nominatim
      },
      {
        name: "BigDataCloud",
        method: :test_bigdatacloud
      },
      {
        name: "LocationIQ (без ключа)",
        method: :test_locationiq
      }
    ]
    
    results = []
    
    services.each_with_index do |service, index|
      puts "#{index + 1}. 🔍 Тестируем #{service[:name]}..."
      
      begin
        result = send(service[:method])
        if result
          results << { service: service[:name], address: result }
          puts "   ✅ Успех: #{result}"
        else
          puts "   ❌ Не удалось получить адрес"
        end
      rescue => e
        puts "   ❌ Ошибка: #{e.message}"
      end
      
      puts ""
      sleep(1) # Пауза между запросами
    end
    
    puts "=" * 50
    puts "🏆 ИТОГИ:"
    
    if results.any?
      puts "✅ Найдено адресов: #{results.length}"
      
      results.each_with_index do |result, index|
        puts "\n#{index + 1}. #{result[:service]}:"
        puts "   📍 #{result[:address]}"
        
        # Проверяем на наличие Padonan
        if result[:address].include?('Padonan')
          puts "   🎯 ОТЛИЧНО! Содержит 'Padonan'"
        elsif result[:address].match?(/Jl\.?\s|Street|Road/)
          puts "   ✅ Содержит название улицы"  
        elsif result[:address].include?('Tibubeneng')
          puts "   ✅ Содержит 'Tibubeneng'"
        end
      end
      
      # Лучший результат
      best_result = results.find { |r| r[:address].include?('Padonan') } || results.first
      puts "\n🥇 ЛУЧШИЙ РЕЗУЛЬТАТ:"
      puts "   #{best_result[:address]}"
      
    else
      puts "❌ Ни один сервис не вернул адрес"
      puts ""
      puts "🤔 Возможные причины:"
      puts "   - Координаты слишком точные для обратного геокодирования"
      puts "   - Локация находится в частной зоне"
      puts "   - Нужны API ключи для точных результатов"
    end
  end
  
  private
  
  def test_nominatim
    # OpenStreetMap Nominatim - бесплатный
    url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=#{@restaurant_lat}&lon=#{@restaurant_lng}&zoom=18&addressdetails=1"
    
    response = make_request(url, {
      'User-Agent' => 'TrackerDelivery/1.0 (test@example.com)'
    })
    
    return nil unless response
    
    data = JSON.parse(response)
    
    if data['display_name']
      return data['display_name']
    elsif data['address']
      # Собираем адрес из частей
      addr = data['address']
      parts = []
      parts << addr['house_number'] if addr['house_number']
      parts << addr['road'] if addr['road']
      parts << addr['suburb'] if addr['suburb'] 
      parts << addr['village'] if addr['village']
      parts << addr['city'] if addr['city']
      parts << addr['state'] if addr['state']
      
      return parts.join(', ') if parts.any?
    end
    
    nil
  end
  
  def test_bigdatacloud
    # BigDataCloud - бесплатный лимит
    url = "https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=#{@restaurant_lat}&longitude=#{@restaurant_lng}&localityLanguage=en"
    
    response = make_request(url)
    return nil unless response
    
    data = JSON.parse(response)
    
    # Пробуем разные поля
    return data['display_name'] if data['display_name']
    
    if data['locality'] || data['city']
      parts = []
      parts << data['locality'] if data['locality']
      parts << data['city'] if data['city']
      parts << data['principalSubdivision'] if data['principalSubdivision']
      parts << data['countryName'] if data['countryName']
      return parts.join(', ')
    end
    
    nil
  end
  
  def test_locationiq
    # LocationIQ - пробуем без ключа
    url = "https://us1.locationiq.com/v1/reverse.php?format=json&lat=#{@restaurant_lat}&lon=#{@restaurant_lng}"
    
    response = make_request(url)
    return nil unless response
    
    data = JSON.parse(response)
    return data['display_name'] if data['display_name']
    
    nil
  rescue => e
    # LocationIQ требует ключ, но попробуем
    nil
  end
  
  def make_request(url, headers = {})
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    headers.each { |key, value| request[key] = value }
    
    response = http.request(request)
    
    if response.code == '200'
      return response.body
    else
      puts "   HTTP #{response.code}: #{response.message}"
      return nil
    end
  end
end

# Запуск тестов
tester = FreeGeocodingTest.new
tester.test_all_services