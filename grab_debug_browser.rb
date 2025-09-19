#!/usr/bin/env ruby

require "selenium-webdriver"

puts "🏪 Grab Address Finder - Debug"
puts ""

begin
  puts "🔧 Настраиваю Chrome драйвер..."
  
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--window-size=1200,800")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  
  puts "🚀 Запускаю Chrome..."
  driver = Selenium::WebDriver.for :chrome, options: options
  
  puts "✅ Chrome запущен успешно!"
  
  url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
  
  puts "📱 Переходим на страницу..."
  driver.navigate.to url
  
  puts "⏱️  Жду загрузки страницы..."
  sleep(5)
  
  puts "📄 Заголовок страницы: #{driver.title}"
  puts "🔗 Текущий URL: #{driver.current_url}"
  
  puts ""
  puts "✅ Браузер готов к работе!"
  puts "🔑 Теперь можете авторизоваться в открывшемся окне Chrome"
  puts ""
  puts "После авторизации:"
  puts "  - Нажмите '1' и Enter для автоматического поиска адреса"
  puts "  - Нажмите '2' и Enter чтобы ввести адрес вручную" 
  puts "  - Нажмите 'q' и Enter для выхода"
  puts ""
  
  loop do
    print "Ваш выбор: "
    input = STDIN.gets
    
    break if input.nil?
    
    input = input.chomp
    
    case input
    when 'q', 'quit'
      puts "🚪 Выходим..."
      break
      
    when '1'
      puts "🔍 Автоматический поиск адреса..."
      
      begin
        page_text = driver.page_source
        title = driver.title
        
        puts "📊 Размер страницы: #{page_text.length} символов"
        puts "📋 Заголовок: #{title}"
        
        # Поиск адреса
        if page_text.include?('Jl. Raya Padonan')
          puts "✅ Найден полный адрес 'Jl. Raya Padonan'!"
        elsif page_text.include?('Padonan')
          puts "✅ Найдено 'Padonan' на странице"
        elsif page_text.include?('Jl. Raya')
          puts "✅ Найдено 'Jl. Raya' на странице"  
        else
          puts "❌ Адрес не найден на странице"
        end
        
        # Ищем элементы с адресом
        begin
          address_elements = driver.find_elements(:xpath, "//*[contains(text(), 'Jl.') or contains(text(), 'Street') or contains(text(), 'Road')]")
          puts "🔍 Найдено #{address_elements.length} элементов с адресными словами"
          
          address_elements.first(3).each_with_index do |element, index|
            text = element.text.strip
            if text.length > 0
              puts "   #{index + 1}: #{text[0..100]}"
            end
          end
        rescue => e
          puts "   Ошибка поиска элементов: #{e.message}"
        end
        
      rescue => e
        puts "❌ Ошибка поиска: #{e.message}"
      end
      
    when '2'
      puts "📝 Введите адрес который вы видите на странице:"
      address = STDIN.gets&.chomp
      
      if address && !address.empty?
        puts "✅ Записан адрес: #{address}"
        if address.include?('Padonan')
          puts "🎯 Отлично! Адрес содержит 'Padonan'"
        end
      else
        puts "❌ Адрес не введен"
      end
      
    else
      puts "❓ Неизвестная команда. Используйте: 1 (поиск), 2 (ввод), q (выход)"
    end
    
    puts ""
  end
  
rescue => e
  puts "❌ Критическая ошибка: #{e.message}"
  puts "Стек: #{e.backtrace.first(3).join("\n")}"
ensure
  if defined?(driver) && driver
    puts "🚪 Закрываю браузер..."
    begin
      driver.quit
    rescue
      puts "⚠️  Браузер уже закрыт"
    end
  end
end

puts "👋 Программа завершена!"