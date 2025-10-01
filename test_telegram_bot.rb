#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class TelegramBotTester
  def initialize
    @bot_token = "8240528344:AAEwwTc84cEBDB-Wuluqq_bsiDhMbf3r-KM"
    @base_url = "https://api.telegram.org/bot#{@bot_token}"
  end
  
  def test_bot_status
    puts "=== Проверка статуса бота ==="
    
    response = make_request("getMe")
    
    if response && response['ok']
      bot_info = response['result']
      puts "✅ Бот активен!"
      puts "👤 Имя: #{bot_info['first_name']}"
      puts "🤖 Username: @#{bot_info['username']}"
      puts "🆔 Bot ID: #{bot_info['id']}"
      puts "🔗 Bot Token: #{@bot_token[0..10]}..."
      return true
    else
      puts "❌ Ошибка: бот не отвечает"
      puts "Response: #{response}" if response
      return false
    end
  rescue => e
    puts "❌ Ошибка подключения: #{e.message}"
    return false
  end
  
  def get_chat_updates
    puts "\n=== Получение обновлений (Chat ID) ==="
    
    response = make_request("getUpdates")
    
    if response && response['ok']
      updates = response['result']
      
      if updates.empty?
        puts "📭 Нет сообщений для бота"
        puts "💬 Напишите боту любое сообщение в Telegram, затем повторите команду"
        return []
      end
      
      puts "📨 Найдено #{updates.length} обновлений:"
      
      chat_ids = []
      updates.each_with_index do |update, index|
        if update['message']
          message = update['message']
          chat = message['chat']
          from = message['from']
          
          chat_id = chat['id']
          chat_ids << chat_id
          
          puts "\n--- Обновление #{index + 1} ---"
          puts "💬 Chat ID: #{chat_id}"
          puts "👤 Имя: #{from['first_name']} #{from['last_name']}".strip
          puts "📝 Username: @#{from['username']}" if from['username']
          puts "📅 Дата: #{Time.at(message['date'])}"
          puts "💭 Текст: #{message['text']}"
          
          if chat['type'] == 'private'
            puts "🔒 Тип чата: Личный"
          else
            puts "👥 Тип чата: #{chat['type']}"
          end
        end
      end
      
      return chat_ids.uniq
      
    else
      puts "❌ Ошибка получения обновлений"
      puts "Response: #{response}" if response
      return []
    end
  rescue => e
    puts "❌ Ошибка: #{e.message}"
    return []
  end
  
  def send_test_message(chat_id)
    puts "\n=== Отправка тестового сообщения ==="
    puts "📤 Отправляем в Chat ID: #{chat_id}"
    
    message_text = "🤖 Тестовое сообщение от TrackerDelivery бота!\n\n" \
                   "✅ Подключение работает\n" \
                   "📅 Время: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n" \
                   "🚨 Готов отправлять уведомления об аномалиях ресторанов!"
    
    params = {
      chat_id: chat_id,
      text: message_text,
      parse_mode: 'HTML'
    }
    
    response = make_request("sendMessage", params)
    
    if response && response['ok']
      puts "✅ Сообщение отправлено успешно!"
      puts "📊 Message ID: #{response['result']['message_id']}"
      return true
    else
      puts "❌ Ошибка отправки сообщения"
      puts "Response: #{response}" if response
      return false
    end
  rescue => e
    puts "❌ Ошибка отправки: #{e.message}"
    return false
  end
  
  def run_full_test
    puts "🤖 ТЕСТИРОВАНИЕ TELEGRAM BOT API"
    puts "=" * 50
    
    # 1. Проверяем статус бота
    unless test_bot_status
      puts "\n❌ Бот не работает. Проверьте токен!"
      return
    end
    
    # 2. Получаем Chat ID
    chat_ids = get_chat_updates
    
    if chat_ids.empty?
      puts "\n📝 ИНСТРУКЦИЯ:"
      puts "1. Найдите бота в Telegram по username (показан выше)"
      puts "2. Напишите боту любое сообщение (например: /start или 'Привет')"
      puts "3. Запустите тест снова: ruby test_telegram_bot.rb"
      return
    end
    
    # 3. Тестируем отправку сообщения
    primary_chat_id = chat_ids.first
    puts "\n🎯 Используем Chat ID: #{primary_chat_id} для тестирования"
    
    if send_test_message(primary_chat_id)
      puts "\n🎉 УСПЕХ! Telegram бот настроен правильно"
      puts "💾 Сохраните этот Chat ID: #{primary_chat_id}"
      puts "📋 Используйте его в notification_contacts таблице"
    end
    
    puts "\n" + "=" * 50
  end
  
  private
  
  def make_request(method, params = {})
    uri = URI("#{@base_url}/#{method}")
    
    if params.any?
      uri.query = URI.encode_www_form(params)
    end
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    puts "JSON Parse Error: #{e.message}"
    puts "Response body: #{response.body}"
    nil
  rescue => e
    puts "HTTP Error: #{e.message}"
    nil
  end
end

# Запуск тестирования
if __FILE__ == $0
  tester = TelegramBotTester.new
  tester.run_full_test
end