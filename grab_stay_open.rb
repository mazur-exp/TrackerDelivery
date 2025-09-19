#!/usr/bin/env ruby

require "selenium-webdriver"

puts "🏪 Grab Address Finder - Long Session"
puts "🎯 Ищем: Jl. Raya Padonan для Prana Kitchen"
puts ""

begin
  puts "🚀 Открываю Chrome браузер..."
  
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--window-size=1400,900")
  
  driver = Selenium::WebDriver.for :chrome, options: options
  
  url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
  
  puts "📱 Открываю страницу ресторана: Prana Kitchen - Tibubeneng"
  driver.navigate.to url
  sleep(3)
  
  puts ""
  puts "✅ Браузер открыт и готов!"
  puts "🔗 URL: #{driver.current_url[0..80]}..."
  puts ""
  puts "📋 ЧТО ДЕЛАТЬ:"
  puts "1. 🔑 Авторизуйтесь в Grab в открывшемся окне"
  puts "2. 🏠 Вернитесь на страницу ресторана после авторизации"  
  puts "3. 👀 Найдите адрес на странице глазами"
  puts "4. 💬 Сообщите мне что нашли"
  puts ""
  puts "⏰ Браузер будет открыт 10 МИНУТ"
  puts "🚫 НЕ ЗАКРЫВАЙТЕ этот терминал!"
  puts ""
  
  # Ждем 10 минут = 600 секунд
  total_seconds = 600
  check_interval = 30  # проверяем каждые 30 секунд
  
  (1..(total_seconds / check_interval)).each do |i|
    minutes_left = (total_seconds - i * check_interval) / 60
    puts "⏱️  Осталось времени: #{minutes_left} минут (проверка #{i})"
    
    begin
      current_title = driver.title
      current_url = driver.current_url
      
      puts "   📄 Заголовок: #{current_title}"
      
      # Проверяем есть ли на странице искомый адрес
      if current_url.include?('restaurant') && !current_url.include?('weblogin')
        page_source = driver.page_source
        
        if page_source.include?('Padonan')
          puts "   🎉 НАЙДЕНО! На странице есть 'Padonan'"
          
          # Попытаемся найти полный адрес
          lines = page_source.split(/\n|>|</)
          padonan_lines = lines.select { |line| line.include?('Padonan') && line.strip.length > 10 && line.strip.length < 200 }
          
          padonan_lines.first(3).each do |line|
            clean = line.strip.gsub(/[<>"]/, '')
            puts "   📍 Возможный адрес: #{clean}" if clean.length > 5
          end
        elsif page_source.include?('Jl. Raya')
          puts "   ✅ На странице есть 'Jl. Raya'"
        else
          puts "   ❌ 'Padonan' пока не найден на странице"
        end
      else
        puts "   ℹ️  Сейчас на странице авторизации или другой странице"
      end
      
    rescue => e
      puts "   ⚠️  Ошибка проверки: #{e.message}"
    end
    
    puts ""
    sleep(check_interval)
  end
  
  puts "⏰ Время истекло!"
  puts "🔍 Финальная проверка..."
  
  begin
    final_url = driver.current_url
    final_title = driver.title
    puts "📄 Финальный заголовок: #{final_title}"
    puts "🔗 Финальный URL: #{final_url[0..100]}..."
    
    if final_url.include?('restaurant')
      page_text = driver.page_source
      if page_text.include?('Padonan')
        puts "🎉 УСПЕХ! Адрес 'Padonan' найден на финальной странице!"
      else
        puts "❌ Адрес не найден на финальной странице"
      end
    end
  rescue => e
    puts "❌ Ошибка финальной проверки: #{e.message}"
  end
  
rescue Interrupt
  puts "\n⚠️  Прервано пользователем (Ctrl+C)"
rescue => e
  puts "❌ Ошибка: #{e.message}"
ensure
  if defined?(driver) && driver
    puts "\n🚪 Закрываю браузер..."
    driver.quit
  end
end

puts "👋 Сессия завершена!"
puts ""
puts "📝 Если вы нашли адрес, пожалуйста, скажите мне что это было!"