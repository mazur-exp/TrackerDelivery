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

# Mock Time.current for Rails compatibility
class Time
  def self.current
    Time.now
  end
end

require_relative 'app/services/cuisine_translation_service'
require_relative 'app/services/gojek_parser_service'

class GojekStressTester
  def initialize
    @gojek_urls = [
      {
        name: "Kue Tiram Ny Hok",
        url: "https://gofood.link/a/Nt5i77d"
      },
      {
        name: "Tiramisu 2Go Bali",
        url: "https://gofood.link/a/QK8wyTj"
      },
      {
        name: "SOMARI Tiramisu Bar, Kuta",
        url: "https://gofood.link/a/PTGZGz7"
      },
      {
        name: "Tiramisu By MilmisyuBali, Badung, Canggu, Tibuneneng",
        url: "https://gofood.link/a/BHZmkmU"
      },
      {
        name: "Nangka Dan Pisang Goreng Siram Cokelat, Jl Tukad Yeh Ho",
        url: "https://gofood.link/a/Q8i9MZw"
      },
      {
        name: "Alex Villas Kitchen 5, Kuta Utara",
        url: "https://gofood.link/a/NsrdBg7"
      },
      {
        name: "La Cucina Pizza & Pasta, Umalas",
        url: "https://gofood.link/a/JqD5PhL"
      },
      {
        name: "Ducat Cafe (Breakfast, Croissant, Salad, Steak), Canggu",
        url: "https://gofood.link/a/MrswDDW"
      }
    ]
  end

  def run_stress_test
    puts "🔵 GOJEK STRESS TEST - ПОЛНОЕ ТЕСТИРОВАНИЕ"
    puts "=" * 80
    puts "📊 Количество заведений: #{@gojek_urls.length}"
    puts "=" * 80
    puts ""

    results = []

    @gojek_urls.each_with_index do |restaurant, index|
      puts ""
      puts "#{index + 1}/#{@gojek_urls.length} - #{restaurant[:name]}"
      puts "-" * 60
      puts "URL: #{restaurant[:url]}"

      start_time = Time.now
      begin
        parser = GojekParserService.new
        result = parser.parse(restaurant[:url])
        duration = Time.now - start_time

        if result
          puts "✅ УСПЕХ (#{duration.round(2)}s)"
          puts "   🏪 Название: #{result[:name]}"
          puts "   📍 Адрес: #{result[:address] || 'Не найден'}"
          puts "   🍽️  Кухни: #{result[:cuisines]&.join(', ') || 'N/A'}"
          puts "   ⭐ Рейтинг: #{result[:rating] || 'N/A'}"
          puts "   🕐 Часы работы: #{result[:working_hours] || 'N/A'}"
          puts "   🖼️  Изображение: #{result[:image_url] ? 'Есть' : 'Нет'}"
          puts "   📱 Статус: #{result[:status] ? result[:status][:status_text] : 'N/A'}"

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
        puts "   Класс: #{e.class}"

        results << {
          name: restaurant[:name],
          success: false,
          duration: duration,
          error: "#{e.class}: #{e.message}"
        }
      end
    end

    print_summary(results)
  end

  private

  def print_summary(results)
    puts "\n\n📊 ИТОГОВАЯ СТАТИСТИКА GOJEK"
    puts "=" * 80

    successful = results.count { |r| r[:success] }
    total = results.length
    success_rate = (successful.to_f / total * 100).round(1)
    avg_time = results.map { |r| r[:duration] }.sum / total

    puts "🔵 GOJEK PARSER:"
    puts "   ✅ Успешно: #{successful}/#{total} (#{success_rate}%)"
    puts "   ⏱️  Среднее время: #{avg_time.round(2)}s"

    if successful < total
      puts "   ❌ Неудачи:"
      results.select { |r| !r[:success] }.each do |result|
        puts "      - #{result[:name]}: #{result[:error]}"
      end
    end

    puts ""
    puts "🏆 ОЦЕНКА ПРОИЗВОДИТЕЛЬНОСТИ:"
    if success_rate >= 90
      puts "   🎉 ОТЛИЧНЫЙ РЕЗУЛЬТАТ! Парсер работает стабильно"
    elsif success_rate >= 75
      puts "   👍 ХОРОШИЙ РЕЗУЛЬТАТ - большинство заведений парсится"
    elsif success_rate >= 50
      puts "   ⚠️  ТРЕБУЕТ УЛУЧШЕНИЯ - половина запросов неуспешна"
    else
      puts "   🚨 КРИТИЧЕСКИЕ ПРОБЛЕМЫ - парсер нуждается в исправлении"
    end

    # Analyze successful results
    if successful > 0
      puts ""
      puts "📈 АНАЛИЗ УСПЕШНЫХ РЕЗУЛЬТАТОВ:"
      successful_results = results.select { |r| r[:success] }

      with_address = successful_results.count { |r| r[:data][:address] && !r[:data][:address].empty? }
      with_cuisines = successful_results.count { |r| r[:data][:cuisines] && r[:data][:cuisines].any? }
      with_rating = successful_results.count { |r| r[:data][:rating] }
      with_hours = successful_results.count { |r| r[:data][:working_hours] }
      with_image = successful_results.count { |r| r[:data][:image_url] }

      puts "   📍 С адресом: #{with_address}/#{successful} (#{(with_address.to_f / successful * 100).round(1)}%)"
      puts "   🍽️  С кухнями: #{with_cuisines}/#{successful} (#{(with_cuisines.to_f / successful * 100).round(1)}%)"
      puts "   ⭐ С рейтингом: #{with_rating}/#{successful} (#{(with_rating.to_f / successful * 100).round(1)}%)"
      puts "   🕐 С часами работы: #{with_hours}/#{successful} (#{(with_hours.to_f / successful * 100).round(1)}%)"
      puts "   🖼️  С изображением: #{with_image}/#{successful} (#{(with_image.to_f / successful * 100).round(1)}%)"
    end

    puts "=" * 80
  end
end

# Run the stress test
if __FILE__ == $0
  tester = GojekStressTester.new
  tester.run_stress_test
end
