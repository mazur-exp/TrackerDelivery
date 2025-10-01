#!/usr/bin/env ruby

require 'ostruct'

# Test Telegram notification system
puts "🧪 Тестирование Telegram уведомлений..."

# Get the restaurant with Telegram contacts
restaurant = Restaurant.joins(:notification_contacts)
                      .where(notification_contacts: { contact_type: 'telegram' })
                      .first

if !restaurant
  puts "❌ Ресторан с Telegram контактами не найден"
  exit
end

puts "🏪 Тестируемый ресторан: #{restaurant.name}"

# Check notification contacts
telegram_contacts = restaurant.notification_contacts.where(contact_type: 'telegram')
puts "📱 Telegram контакты:"
telegram_contacts.each do |contact|
  puts "  - Username: #{contact.contact_value}"
  puts "    Chat ID: #{contact.telegram_chat_id}"
  puts "    Display: #{contact.display_value}"
end

# Create a fake status check for testing
fake_status_check = OpenStruct.new(
  severity: :critical,
  anomaly_description: "Ресторан закрыт, но должен быть открыт",
  expected_status: "open",
  actual_status: "closed",
  checked_at: Time.current
)

puts "\n🚨 Создаем тестовое уведомление об аномалии..."
puts "Параметры:"
puts "  - Ожидаемый статус: #{fake_status_check.expected_status}"
puts "  - Фактический статус: #{fake_status_check.actual_status}"
puts "  - Серьезность: #{fake_status_check.severity}"

# Send notification
begin
  notification_service = NotificationService.new
  notification_service.send_restaurant_anomaly_alert(restaurant, fake_status_check)
  puts "\n✅ Уведомление отправлено успешно!"
  puts "📲 Проверьте Telegram для получения сообщения"
rescue => e
  puts "\n❌ Ошибка при отправке уведомления:"
  puts "   #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

puts "\n" + "="*50