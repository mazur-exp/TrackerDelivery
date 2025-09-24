#!/usr/bin/env ruby

# Mock Rails logger for testing
class MockLogger
  def info(message)
    puts "[INFO] #{message}"
  end

  def error(message)
    puts "[ERROR] #{message}"
  end

  def warn(message)
    puts "[WARN] #{message}"
  end
end

module Rails
  def self.logger
    @logger ||= MockLogger.new
  end
end

# Mock ActiveSupport methods
class String
  def blank?
    self.nil? || self.strip.empty?
  end

  def present?
    !blank?
  end
end

class NilClass
  def blank?
    true
  end

  def present?
    false
  end
end

class Array
  def blank?
    self.empty?
  end

  def present?
    !blank?
  end
end

class Time
  def self.current
    Time.now
  end
end

require_relative 'app/services/cuisine_translation_service'
require_relative 'app/services/gojek_parser_service'

# Test URLs that previously returned no rating
test_urls = [
  {
    name: "Tiramisu 2Go Bali (предположительно NEW)",
    url: "https://gofood.link/a/QK8wyTj"
  },
  {
    name: "SOMARI Tiramisu Bar (предположительно NEW)",
    url: "https://gofood.link/a/PTGZGz7"
  }
]

test_urls.each do |restaurant|
  puts "\n" + "=" * 80
  puts "🔍 ТЕСТ NEW РЕЙТИНГА: #{restaurant[:name]}"
  puts "=" * 80

  begin
    parser = GojekParserService.new
    result = parser.parse(restaurant[:url])

    if result
      puts "✅ РЕЗУЛЬТАТ ПАРСИНГА:"
      puts "   🏪 Название: #{result[:name]}"
      puts "   ⭐ Рейтинг: #{result[:rating] || 'N/A'}"

      if result[:rating] == "NEW"
        puts "   🆕 НАЙДЕН ИНДИКАТОР 'NEW' - заведение новое!"
      elsif result[:rating].is_a?(Numeric)
        puts "   📊 Числовой рейтинг: #{result[:rating]}"
      else
        puts "   ❓ Рейтинг не найден"
      end
    else
      puts "❌ ПАРСЕР ВЕРНУЛ NIL"
    end
  rescue => e
    puts "💥 ОШИБКА: #{e.message}"
  end
end
