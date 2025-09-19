#!/usr/bin/env ruby

require "selenium-webdriver"

class GrabManualSession
  def initialize
    @restaurant_url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
  end
  
  def start_manual_session
    driver = nil
    
    begin
      puts "🚀 Открываю браузер для ручной работы..."
      puts "=" * 60
      
      # Setup Chrome driver - НЕ headless режим
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--window-size=1400,900")
      options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36")
      
      driver = Selenium::WebDriver.for :chrome, options: options
      
      puts "📱 Открываю страницу ресторана..."
      driver.navigate.to @restaurant_url
      
      puts ""
      puts "🔑 ПОШАГОВЫЕ ИНСТРУКЦИИ:"
      puts "=" * 40
      puts "1. Браузер открыт и показывает страницу ресторана"
      puts "2. Найдите и нажмите кнопку 'Login' или 'Войти'"  
      puts "3. Войдите в свой аккаунт Grab"
      puts "4. Вернитесь на страницу ресторана"
      puts "5. Поищите адрес на странице глазами"
      puts ""
      puts "⏰ У ВАС ЕСТЬ СКОЛЬКО УГОДНО ВРЕМЕНИ!"
      puts "🚫 Браузер НЕ ЗАКРОЕТСЯ автоматически"
      puts ""
      
      loop do
        puts "Выберите действие:"
        puts "  1 - Поиск адреса автоматически (после авторизации)"
        puts "  2 - Ввести адрес вручную"
        puts "  3 - Показать текущий URL"
        puts "  4 - Обновить страницу"
        puts "  5 - Выход"
        puts ""
        print "Ваш выбор (1-5): "
        
        choice = STDIN.gets.strip
        puts ""
        
        case choice
        when "1"
          puts "🔍 Запускаю автоматический поиск адреса..."
          result = search_for_address(driver)
          if result
            puts "✅ Найдено: #{result}"
          else
            puts "❌ Адрес не найден автоматически"
          end
          puts ""
          
        when "2"
          print "Введите адрес который вы видите на странице: "
          manual_address = STDIN.gets.strip
          if !manual_address.empty?
            puts "✅ Записан адрес: #{manual_address}"
            puts "🎯 Содержит 'Jl. Raya Padonan'?: #{manual_address.include?('Padonan') ? 'ДА' : 'НЕТ'}"
          end
          puts ""
          
        when "3"
          current_url = driver.current_url
          puts "📍 Текущий URL: #{current_url}"
          puts ""
          
        when "4"
          puts "🔄 Обновляю страницу..."
          driver.navigate.refresh
          sleep(2)
          puts "✅ Страница обновлена"
          puts ""
          
        when "5"
          puts "🚪 Выходим..."
          break
          
        else
          puts "❌ Неверный выбор, попробуйте еще раз"
          puts ""
        end
      end
      
    rescue Interrupt
      puts "\n⚠️  Прервано пользователем (Ctrl+C)"
    rescue => e
      puts "\n❌ Ошибка: #{e.message}"
    ensure
      if driver
        puts "\n🚪 Закрываю браузер..."
        driver.quit
      end
    end
  end
  
  private
  
  def search_for_address(driver)
    begin
      # Простой поиск в тексте страницы
      page_text = driver.page_source
      
      # Ищем строки с адресом
      if page_text.include?('Jl. Raya Padonan')
        # Извлекаем контекст вокруг найденной строки
        lines = page_text.split(/\n|<|>/)
        lines.each do |line|
          clean_line = line.strip.gsub(/[<>"]/, '')
          if clean_line.include?('Jl. Raya Padonan') && clean_line.length < 100
            return clean_line
          end
        end
        return "Найдено 'Jl. Raya Padonan' на странице"
      end
      
      if page_text.include?('Padonan')
        lines = page_text.split(/\n|<|>/)
        lines.each do |line|
          clean_line = line.strip.gsub(/[<>"]/, '')
          if clean_line.include?('Padonan') && clean_line.length > 10 && clean_line.length < 100
            return clean_line
          end
        end
        return "Найдено 'Padonan' на странице"
      end
      
      # Поиск через XPath
      selectors = [
        "//*[contains(text(), 'Jl.')]",
        "//*[contains(text(), 'Street')]",
        "//*[contains(text(), 'Road')]",
        "//*[contains(@class, 'address')]",
        "//*[contains(text(), 'Tibubeneng') and string-length(text()) > 15]"
      ]
      
      selectors.each do |selector|
        elements = driver.find_elements(:xpath, selector)
        elements.each do |element|
          text = element.text.strip
          if text.length > 10 && text.length < 200
            if text.match?(/jl\.|street|road|address/i)
              return text
            end
          end
        end
      end
      
      nil
      
    rescue => e
      puts "Ошибка поиска: #{e.message}"
      nil
    end
  end
end

# Запуск
puts "🏪 Grab Address Finder - Ручная сессия"
puts "🎯 Ищем: Jl. Raya Padonan для Prana Kitchen"
puts "📋 Ресторан: Prana Kitchen - Tibubeneng"
puts ""

session = GrabManualSession.new
session.start_manual_session