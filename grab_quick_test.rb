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

class Time
  def self.current
    Time.now
  end
end

require_relative 'app/services/grab_parser_service'

grab_urls = [
  {
    name: "Healthy Fit (Bowl, Pasta, Salad, Wrap), Bali - Canggu",
    url: "https://r.grab.com/g/6-20250920_121514_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C65ZV62KVNEDPE"
  },
  {
    name: "Healthy Friends - Canggu - Canggu",
    url: "https://r.grab.com/g/6-20250920_121529_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C7EYJXBKG3AUGE"
  },
  {
    name: "Ducat Cafe (Healthy Breakfast, Salad) - Tibubeneng",
    url: "https://r.grab.com/g/6-20250920_121543_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C6VDCKJTLZKCCA"
  },
  {
    name: "Salaterai Berawa - Tibubeneng",
    url: "https://r.grab.com/g/6-20250920_121618_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C65UAJXBTCMXAJ"
  },
  {
    name: "SAMA SAMA PRIME - Tibubeneng",
    url: "https://r.grab.com/g/6-20250920_121630_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C3WXLGNUT2CZCX"
  },
  {
    name: "Food Romance - Tibubeneng",
    url: "https://r.grab.com/g/6-20250920_121639_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C4JCTF31T2NACX"
  }
]

puts "🟢 GRAB PARSER QUICK TEST"
puts "=" * 60
puts "📊 Количество заведений: #{grab_urls.length}"
puts "=" * 60

results = []
total_start = Time.now

grab_urls.each_with_index do |restaurant, index|
  puts "\n#{index + 1}/#{grab_urls.length} - #{restaurant[:name]}"
  puts "-" * 50
  puts "URL: #{restaurant[:url]}"

  start_time = Time.now
  begin
    parser = GrabParserService.new
    result = parser.parse(restaurant[:url])
    duration = Time.now - start_time

    if result
      puts "✅ УСПЕХ (#{duration.round(2)}s)"
      puts "   🏪 Название: #{result[:name]}"
      puts "   📍 Адрес: #{result[:address] || 'Не найден'}"
      puts "   🍽️  Кухни: #{result[:cuisines]&.join(', ') || 'N/A'}"
      puts "   ⭐ Рейтинг: #{result[:rating] || 'N/A'}"
      puts "   🕐 Часы работы: #{result[:working_hours]&.length || 0} записей"
      puts "   🖼️  Изображение: #{result[:image_url] ? 'Есть' : 'Нет'}"
      puts "   📱 Статус: #{result[:status][:status_text] if result[:status]}"

      results << {
        name: restaurant[:name],
        success: true,
        duration: duration,
        data: result
      }
    else
      puts "❌ ОШИБКА (#{duration.round(2)}s)"
      puts "   Парсер вернул nil"

      results << {
        name: restaurant[:name],
        success: false,
        duration: duration,
        error: "Parser returned nil"
      }
    end
  rescue => e
    duration = Time.now - start_time
    puts "💥 ИСКЛЮЧЕНИЕ (#{duration.round(2)}s)"
    puts "   Ошибка: #{e.message}"

    results << {
      name: restaurant[:name],
      success: false,
      duration: duration,
      error: e.message
    }
  end
end

total_duration = Time.now - total_start

# Statistics
successful = results.count { |r| r[:success] }
total = results.length
success_rate = (successful.to_f / total * 100).round(1)
avg_time = results.map { |r| r[:duration] }.sum / total

puts "\n\n📊 GRAB СТАТИСТИКА"
puts "=" * 60
puts "✅ Успешно: #{successful}/#{total} (#{success_rate}%)"
puts "⏱️  Среднее время: #{avg_time.round(2)}s"
puts "🏁 Общее время: #{total_duration.round(2)}s"
puts "⚡ Скорость: #{(total.to_f / total_duration * 60).round(1)} заведений/мин"

if successful > 0
  successful_results = results.select { |r| r[:success] }

  with_address = successful_results.count { |r| r[:data][:address] && !r[:data][:address].empty? }
  with_cuisines = successful_results.count { |r| r[:data][:cuisines] && r[:data][:cuisines].any? }
  with_rating = successful_results.count { |r| r[:data][:rating] }
  with_hours = successful_results.count { |r| r[:data][:working_hours] && r[:data][:working_hours].any? }
  with_image = successful_results.count { |r| r[:data][:image_url] }

  puts "\n📈 КАЧЕСТВО ДАННЫХ:"
  puts "   📍 С адресом: #{with_address}/#{successful} (#{(with_address.to_f / successful * 100).round(1)}%)"
  puts "   🍽️  С кухнями: #{with_cuisines}/#{successful} (#{(with_cuisines.to_f / successful * 100).round(1)}%)"
  puts "   ⭐ С рейтингом: #{with_rating}/#{successful} (#{(with_rating.to_f / successful * 100).round(1)}%)"
  puts "   🕐 С часами работы: #{with_hours}/#{successful} (#{(with_hours.to_f / successful * 100).round(1)}%)"
  puts "   🖼️  С изображением: #{with_image}/#{successful} (#{(with_image.to_f / successful * 100).round(1)}%)"
end

puts "=" * 60
