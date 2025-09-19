#!/usr/bin/env ruby

require "selenium-webdriver"

puts "🏪 Grab Address Finder - Простая сессия"
puts "🎯 Ищем: Jl. Raya Padonan для Prana Kitchen"
puts ""
puts "🚀 Открываю браузер..."

begin
  # Setup Chrome - видимый режим
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--window-size=1400,900")
  
  driver = Selenium::WebDriver.for :chrome, options: options
  
  url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
  
  puts "📱 Открываю страницу ресторана..."
  driver.navigate.to url
  
  puts ""
  puts "✅ Браузер открыт!"
  puts "🔑 Авторизуйтесь в Grab в открывшемся окне"
  puts "🔍 Найдите адрес на странице"
  puts ""
  puts "Нажмите Enter чтобы начать автоматический поиск, или введите 'quit' для выхода:"
  
  loop do
    input = gets
    if input.nil?
      break
    end
    
    input = input.chomp.downcase
    
    if input == "quit" || input == "q"
      break
    elsif input == ""
      puts "🔍 Ищу адрес автоматически..."
      
      # Простой поиск
      page_source = driver.page_source
      
      if page_source.include?('Padonan')
        puts "✅ Найдено 'Padonan' на странице!"
        
        # Попробуем извлечь точный адрес
        lines = page_source.split("\n")
        lines.each do |line|
          if line.include?('Padonan') && line.length < 200
            clean = line.gsub(/<[^>]*>/, '').strip
            if clean.length > 20 && clean.length < 150
              puts "📍 Возможный адрес: #{clean}"
            end
          end
        end
      else
        puts "❌ 'Padonan' не найден на странице"
      end
      
      puts ""
      puts "Нажмите Enter для повторного поиска или 'quit' для выхода:"
    else
      puts "Команды: Enter (поиск) или 'quit' (выход)"
    end
  end
  
rescue Interrupt
  puts "\n⚠️  Прервано пользователем"
rescue => e
  puts "❌ Ошибка: #{e.message}"
ensure
  if defined?(driver) && driver
    puts "🚪 Закрываю браузер..."
    driver.quit
  end
end

puts "👋 Завершено!"