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

# Test the two problematic URLs
problem_urls = [
  {
    name: "Tiramisu By MilmisyuBali",
    url: "https://gofood.link/a/BHZmkmU"
  },
  {
    name: "Ducat Cafe",
    url: "https://gofood.link/a/MrswDDW"
  }
]

problem_urls.each do |restaurant|
  puts "\n" + "=" * 80
  puts "🔍 ПРОВЕРКА: #{restaurant[:name]}"
  puts "URL: #{restaurant[:url]}"
  puts "=" * 80

  begin
    parser = GojekParserService.new
    result = parser.parse(restaurant[:url])

    if result
      puts "✅ РЕЗУЛЬТАТ ПАРСИНГА:"
      puts "   Название: #{result[:name]}"
      puts "   Адрес: #{result[:address] || 'Не найден'}"
      puts "   Кухни: #{result[:cuisines]&.join(', ') || 'N/A'}"
      puts "   Рейтинг: #{result[:rating] || 'N/A'}"
      puts "   Статус: #{result[:status][:status_text] if result[:status]}"
    else
      puts "❌ ПАРСЕР ВЕРНУЛ NIL"
    end
  rescue => e
    puts "💥 ОШИБКА: #{e.message}"
    puts "Класс: #{e.class}"
    puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
  end
end
