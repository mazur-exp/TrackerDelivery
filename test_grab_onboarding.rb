require_relative "config/environment"

puts "=== ТЕСТИРОВАНИЕ GRAB ПАРСЕРА НА ОНБОРДИНГЕ ==="
puts

# URL от пользователя 
grab_url = "https://r.grab.com/g/6-20250920_121514_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C65ZV62KVNEDPE"
puts "URL: #{grab_url}"
puts

# Запускаем полный парсер (как на онбординге)
puts "Запускаем ПОЛНЫЙ парсер (метод parse)..."
begin
  result = GrabParserService.new.parse(grab_url)
  puts "Результат:"
  if result
    puts result.inspect
  else
    puts "nil - ПРОБЛЕМА!"
  end
rescue => e
  puts "ОШИБКА: #{e.message}"
  puts "Backtrace:"
  puts e.backtrace.first(5)
end

puts
puts "=" * 50
puts

# Для сравнения - тестируем check_status_only
puts "Запускаем метод check_status_only (работает в мониторинге)..."
begin
  status_result = GrabParserService.new.check_status_only(grab_url) 
  puts "Результат статуса:"
  puts status_result.inspect
rescue => e
  puts "ОШИБКА в check_status_only: #{e.message}"
end