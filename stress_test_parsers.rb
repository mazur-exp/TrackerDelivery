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

# Mock Time.current for Rails compatibility
class Time
  def self.current
    Time.now
  end
end

require_relative 'app/services/cuisine_translation_service'
require_relative 'app/services/gojek_parser_service'
require_relative 'app/services/grab_parser_service'

class ParserStressTester
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

    @grab_urls = [
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
  end

  def run_stress_test
    puts "🔥 STRESS TEST ПАРСЕРОВ - ЗАПУСК"
    puts "=" * 80
    puts "📊 GoJek URLs: #{@gojek_urls.length}"
    puts "📊 Grab URLs: #{@grab_urls.length}"
    puts "📊 Общий объем: #{@gojek_urls.length + @grab_urls.length} заведений"
    puts "=" * 80
    puts ""

    gojek_results = []
    grab_results = []

    # Test GoJek Parser
    puts "🔵 ТЕСТИРОВАНИЕ GOJEK PARSER"
    puts "=" * 60

    @gojek_urls.each_with_index do |restaurant, index|
      puts ""
      puts "#{index + 1}/#{@gojek_urls.length} - #{restaurant[:name]}"
      puts "-" * 50
      puts "URL: #{restaurant[:url]}"

      start_time = Time.now
      begin
        parser = GojekParserService.new
        result = parser.parse(restaurant[:url])
        duration = Time.now - start_time

        if result
          puts "✅ УСПЕХ (#{duration.round(2)}s)"
          puts "   Название: #{result[:name]}"
          puts "   Адрес: #{result[:address]}"
          puts "   Кухни: #{result[:cuisines]&.join(', ') || 'N/A'}"
          puts "   Рейтинг: #{result[:rating] || 'N/A'}"
          puts "   Часы работы: #{result[:working_hours] || 'N/A'}"
          puts "   Изображение: #{result[:image_url] ? 'Есть' : 'Нет'}"

          gojek_results << {
            name: restaurant[:name],
            success: true,
            duration: duration,
            data: result
          }
        else
          puts "❌ ОШИБКА (#{duration.round(2)}s)"
          puts "   Парсер вернул nil"

          gojek_results << {
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

        gojek_results << {
          name: restaurant[:name],
          success: false,
          duration: duration,
          error: e.message
        }
      end
    end

    # Test Grab Parser
    puts "\n\n🟢 ТЕСТИРОВАНИЕ GRAB PARSER"
    puts "=" * 60

    @grab_urls.each_with_index do |restaurant, index|
      puts ""
      puts "#{index + 1}/#{@grab_urls.length} - #{restaurant[:name]}"
      puts "-" * 50
      puts "URL: #{restaurant[:url]}"

      start_time = Time.now
      begin
        parser = GrabParserService.new
        result = parser.parse(restaurant[:url])
        duration = Time.now - start_time

        if result
          puts "✅ УСПЕХ (#{duration.round(2)}s)"
          puts "   Название: #{result[:name]}"
          puts "   Адрес: #{result[:address]}"
          puts "   Кухни: #{result[:cuisines]&.join(', ') || 'N/A'}"
          puts "   Рейтинг: #{result[:rating] || 'N/A'}"
          puts "   Часы работы: #{result[:working_hours] || 'N/A'}"
          puts "   Изображение: #{result[:image_url] ? 'Есть' : 'Нет'}"

          grab_results << {
            name: restaurant[:name],
            success: true,
            duration: duration,
            data: result
          }
        else
          puts "❌ ОШИБКА (#{duration.round(2)}s)"
          puts "   Парсер вернул nil"

          grab_results << {
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

        grab_results << {
          name: restaurant[:name],
          success: false,
          duration: duration,
          error: e.message
        }
      end
    end

    # Print summary
    print_summary(gojek_results, grab_results)
  end

  private

  def print_summary(gojek_results, grab_results)
    puts "\n\n📊 ИТОГОВАЯ СТАТИСТИКА"
    puts "=" * 80

    # GoJek Statistics
    gojek_successful = gojek_results.count { |r| r[:success] }
    gojek_total = gojek_results.length
    gojek_success_rate = (gojek_successful.to_f / gojek_total * 100).round(1)
    gojek_avg_time = gojek_results.map { |r| r[:duration] }.sum / gojek_total

    puts "🔵 GOJEK PARSER:"
    puts "   Успешно: #{gojek_successful}/#{gojek_total} (#{gojek_success_rate}%)"
    puts "   Среднее время: #{gojek_avg_time.round(2)}s"

    if gojek_successful < gojek_total
      puts "   ❌ Неудачи:"
      gojek_results.select { |r| !r[:success] }.each do |result|
        puts "      - #{result[:name]}: #{result[:error]}"
      end
    end

    # Grab Statistics
    grab_successful = grab_results.count { |r| r[:success] }
    grab_total = grab_results.length
    grab_success_rate = (grab_successful.to_f / grab_total * 100).round(1)
    grab_avg_time = grab_results.map { |r| r[:duration] }.sum / grab_total

    puts ""
    puts "🟢 GRAB PARSER:"
    puts "   Успешно: #{grab_successful}/#{grab_total} (#{grab_success_rate}%)"
    puts "   Среднее время: #{grab_avg_time.round(2)}s"

    if grab_successful < grab_total
      puts "   ❌ Неудачи:"
      grab_results.select { |r| !r[:success] }.each do |result|
        puts "      - #{result[:name]}: #{result[:error]}"
      end
    end

    # Overall Statistics
    total_successful = gojek_successful + grab_successful
    total_requests = gojek_total + grab_total
    overall_success_rate = (total_successful.to_f / total_requests * 100).round(1)

    puts ""
    puts "🏆 ОБЩАЯ СТАТИСТИКА:"
    puts "   Всего заведений: #{total_requests}"
    puts "   Успешно спарсено: #{total_successful}"
    puts "   Общий процент успеха: #{overall_success_rate}%"

    if overall_success_rate >= 90
      puts "   🎉 ОТЛИЧНЫЙ РЕЗУЛЬТАТ!"
    elsif overall_success_rate >= 75
      puts "   👍 ХОРОШИЙ РЕЗУЛЬТАТ"
    elsif overall_success_rate >= 50
      puts "   ⚠️  ТРЕБУЕТ УЛУЧШЕНИЯ"
    else
      puts "   🚨 КРИТИЧЕСКИЕ ПРОБЛЕМЫ"
    end

    puts "=" * 80
  end
end

# Run the stress test
if __FILE__ == $0
  tester = ParserStressTester.new
  tester.run_stress_test
end
