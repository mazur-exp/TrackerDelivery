#!/usr/bin/env ruby

require "selenium-webdriver"
require "timeout"
require "json"

class GrabInteractiveAuthV2
  def initialize
    @restaurant_url = "https://r.grab.com/g/6-20250919_185624_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4J1HGK3N33WR2"
  end
  
  def interactive_session
    driver = nil
    
    begin
      puts "🚀 Starting interactive browser session..."
      puts "=" * 80
      puts ""
      
      # Setup Chrome driver in visible mode
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--disable-web-security")
      options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36")
      
      # Make window bigger for better visibility
      options.add_argument("--window-size=1200,800")
      
      driver = Selenium::WebDriver.for :chrome, options: options
      
      puts "📱 Opening Grab restaurant page..."
      driver.navigate.to @restaurant_url
      
      sleep(3)
      
      puts ""
      puts "🔑 ИНСТРУКЦИИ ДЛЯ АВТОРИЗАЦИИ:"
      puts "=" * 50
      puts "1️⃣  В открывшемся браузере найдите кнопку 'Login' или 'Sign Up'"
      puts "2️⃣  Войдите в свой аккаунт Grab"
      puts "3️⃣  После входа вернитесь на страницу ресторана если перенаправит"
      puts "4️⃣  Проверьте, появился ли адрес ресторана на странице"
      puts "5️⃣  Нажмите ENTER в терминале когда закончите"
      puts ""
      puts "⏰ Времени: НЕОГРАНИЧЕННО (нажмите Ctrl+C для отмены)"
      puts "🔍 Ищем: адрес содержащий 'Jl. Raya Padonan'"
      puts ""
      
      # Ожидаем нажатия Enter без таймаута
      puts "✋ Нажмите ENTER когда авторизация завершена и вы готовы к поиску адреса..."
      STDIN.gets
      
      puts ""
      puts "🔍 Начинаю поиск адреса после авторизации..."
      puts "=" * 50
      
      # Обновляем страницу для получения свежих данных
      puts "🔄 Обновляю страницу для получения актуальных данных..."
      driver.navigate.refresh
      sleep(5)
      
      # Поиск методов
      results = []
      
      # Method 1: Поиск в DOM
      puts "\n🔍 Метод 1: Поиск в DOM элементах..."
      dom_result = advanced_dom_search(driver)
      results << "DOM: #{dom_result}" if dom_result
      
      # Method 2: Поиск в JSON
      puts "\n🔍 Метод 2: Анализ JSON данных..."
      json_result = deep_json_search(driver)
      results << "JSON: #{json_result}" if json_result
      
      # Method 3: JavaScript поиск
      puts "\n🔍 Метод 3: JavaScript поиск..."
      js_result = comprehensive_js_search(driver)
      results << "JavaScript: #{js_result}" if js_result
      
      # Method 4: Поиск по координатам
      puts "\n🔍 Метод 4: Проверка координат..."
      coords_result = check_coordinates(driver)
      results << "Coordinates: #{coords_result}" if coords_result
      
      # Результаты
      puts "\n" + "=" * 80
      puts "🏠 РЕЗУЛЬТАТЫ ПОИСКА АДРЕСА"
      puts "=" * 80
      
      if results && results.any?
        puts "✅ НАЙДЕНО:"
        results.each_with_index do |result, index|
          puts "   #{index + 1}. #{result}"
        end
      else
        puts "❌ Адрес не найден"
        puts ""
        puts "🤔 Возможные причины:"
        puts "   • Ресторан не предоставляет публичный адрес"
        puts "   • Нужны дополнительные разрешения"
        puts "   • Адрес загружается асинхронно"
      end
      
      # Manual inspection
      puts "\n" + "=" * 80
      puts "🔎 РУЧНАЯ ПРОВЕРКА"
      puts "=" * 80
      puts "Браузер остается открытым для ручной проверки."
      puts "Посмотрите на страницу и найдите адрес глазами."
      puts ""
      puts "Введите адрес вручную если видите его (или Enter чтобы пропустить):"
      
      manual_address = STDIN.gets.strip
      if !manual_address.empty?
        puts "✅ Ручно введенный адрес: #{manual_address}"
        results << "Manual: #{manual_address}"
      end
      
      puts "\n🔄 Оставляю браузер открытым еще на 60 секунд для изучения..."
      puts "💡 Можете изучить элементы страницы через Developer Tools"
      
      sleep(60)
      
    rescue Interrupt
      puts "\n⚠️  Прервано пользователем"
    rescue => e
      puts "\n❌ Ошибка: #{e.message}"
    ensure
      if driver
        puts "\n🚪 Закрываю браузер..."
        driver.quit
      end
      
      puts "\n📋 Финальный отчет:"
      if results && results.any?
        results.each { |r| puts "   #{r}" }
      else
        puts "   Адрес не найден автоматически"
      end
    end
  end
  
  private
  
  def advanced_dom_search(driver)
    # Более широкий поиск
    search_patterns = [
      # Прямые адресные паттерны
      "//*[contains(text(), 'Jl. Raya Padonan')]",
      "//*[contains(text(), 'Padonan')]",
      "//*[contains(text(), 'Jl. Raya')]",
      
      # Адресные элементы
      "//div[contains(@class, 'address') or contains(@id, 'address')]",
      "//*[@data-address]",
      "//*[contains(@aria-label, 'address')]",
      
      # Локация элементы
      "//*[contains(@class, 'location') or contains(@id, 'location')]",
      "//*[contains(text(), 'Street') or contains(text(), 'Road')]",
      
      # Длинный текст содержащий Tibubeneng
      "//*[contains(text(), 'Tibubeneng') and string-length(text()) > 15]"
    ]
    
    found_addresses = []
    
    search_patterns.each_with_index do |pattern, index|
      begin
        elements = driver.find_elements(:xpath, pattern)
        puts "   Паттерн #{index + 1}: найдено #{elements.length} элементов"
        
        elements.each do |element|
          text = element.text.strip
          next if text.empty? || text.length < 5
          
          # Проверяем на адресоподобный текст
          if text.match?(/jl\.|street|road|padonan|tibubeneng/i) && text.length > 10
            found_addresses << text
            puts "     Найден: #{text}"
          end
        end
      rescue => e
        puts "     Ошибка с паттерном #{index + 1}: #{e.message}"
      end
    end
    
    found_addresses.uniq.first
  end
  
  def deep_json_search(driver)
    begin
      scripts = driver.find_elements(:css, "script")
      
      scripts.each_with_index do |script, index|
        content = script.attribute("innerHTML")
        next unless content&.include?('props')
        
        # Ищем любые JSON данные, не только ssrRestaurantData
        json_matches = content.scan(/\{[^{}]*"address"[^{}]*\}/)
        json_matches.each do |match|
          begin
            parsed = JSON.parse(match)
            if parsed['address'] && !parsed['address'].to_s.empty?
              puts "   Найден address в script #{index}: #{parsed['address']}"
              return parsed['address'].to_s
            end
          rescue JSON::ParserError
            next
          end
        end
        
        # Ищем строки содержащие адрес
        if content.include?('Padonan') || content.include?('Jl. Raya')
          lines = content.split("\n")
          lines.each do |line|
            if line.include?('Padonan') || line.include?('Jl. Raya')
              clean_line = line.strip.gsub(/[",\\]/, ' ').squeeze(' ')
              if clean_line.length < 200
                puts "   Найдена строка с адресом: #{clean_line}"
                return clean_line
              end
            end
          end
        end
      end
      
      nil
    rescue => e
      puts "   Ошибка JSON поиска: #{e.message}"
      nil
    end
  end
  
  def comprehensive_js_search(driver)
    js_searches = [
      # Поиск во всех текстовых узлах
      """
      var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
      var addresses = [];
      var node;
      while (node = walker.nextNode()) {
        var text = node.textContent.trim();
        if ((text.includes('Jl.') || text.includes('Padonan') || text.includes('Street')) && text.length > 10 && text.length < 200) {
          addresses.push(text);
        }
      }
      return addresses.join(' | ');
      """,
      
      # Поиск в data атрибутах
      """
      var elements = document.querySelectorAll('*');
      for (var i = 0; i < elements.length; i++) {
        var attrs = elements[i].attributes;
        for (var j = 0; j < attrs.length; j++) {
          if (attrs[j].value && (attrs[j].value.includes('Padonan') || attrs[j].value.includes('Jl.'))) {
            return attrs[j].name + ': ' + attrs[j].value;
          }
        }
      }
      return null;
      """,
      
      # Поиск в window объектах
      """
      var keys = Object.keys(window);
      for (var i = 0; i < keys.length; i++) {
        try {
          var obj = window[keys[i]];
          if (obj && typeof obj === 'object' && JSON.stringify(obj).includes('Padonan')) {
            return keys[i] + ': contains Padonan';
          }
        } catch(e) {}
      }
      return null;
      """
    ]
    
    js_searches.each_with_index do |js, index|
      begin
        result = driver.execute_script(js)
        if result && !result.to_s.strip.empty?
          clean_result = result.to_s.strip
          puts "   JS поиск #{index + 1}: #{clean_result}"
          if clean_result.include?('Padonan') || clean_result.include?('Jl.')
            return clean_result
          end
        end
      rescue => e
        puts "   JS ошибка #{index + 1}: #{e.message}"
      end
    end
    
    nil
  end
  
  def check_coordinates(driver)
    begin
      # Получаем координаты из JSON
      scripts = driver.find_elements(:css, "script")
      
      scripts.each do |script|
        content = script.attribute("innerHTML")
        next unless content&.include?('latitude') && content&.include?('longitude')
        
        # Ищем паттерн координат
        lat_match = content.match(/"latitude":\s*(-?\d+\.?\d*)/)
        lng_match = content.match(/"longitude":\s*(-?\d+\.?\d*)/)
        
        if lat_match && lng_match
          lat = lat_match[1]
          lng = lng_match[1]
          puts "   Координаты: #{lat}, #{lng}"
          
          # Если это координаты ресторана (не Jakarta)
          if lat.to_f.abs > 8.0  # Jakarta около -6, Bali около -8
            return "Coordinates: #{lat}, #{lng} (Bali area - можно использовать для геокодирования)"
          end
        end
      end
      
      nil
    rescue => e
      puts "   Ошибка координат: #{e.message}"
      nil
    end
  end
end

# Запуск
puts "🏪 Grab Address Extractor - Interactive V2"
puts "🎯 Цель: найти адрес 'Jl. Raya Padonan' для Prana Kitchen"
puts ""

auth = GrabInteractiveAuthV2.new
auth.interactive_session