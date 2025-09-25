#!/usr/bin/env ruby
require_relative "config/environment"

puts "=== ТЕСТИРОВАНИЕ AUTO-FILL ФУНКЦИОНАЛЬНОСТИ ==="
puts

# Найдем первого пользователя с ресторанами
user_with_restaurants = User.joins(:restaurants).first

if user_with_restaurants.nil?
  puts "❌ Не найден пользователь с ресторанами для тестирования"
  puts "Создайте пользователя с ресторанами или используйте существующего"
  exit 1
end

puts "✅ Найден пользователь ID: #{user_with_restaurants.id}"
puts "   Email: #{user_with_restaurants.email}" if user_with_restaurants.respond_to?(:email)
puts "   Количество ресторанов: #{user_with_restaurants.restaurants.count}"
puts

# Проверим методы auto-fill
puts "=== ПРОВЕРКА МЕТОДОВ AUTO-FILL ==="

# Тестируем all_whatsapp_contacts
whatsapp_contacts = user_with_restaurants.all_whatsapp_contacts
puts "WhatsApp контакты: #{whatsapp_contacts.inspect}"

# Тестируем all_telegram_contacts  
telegram_contacts = user_with_restaurants.all_telegram_contacts
puts "Telegram контакты: #{telegram_contacts.inspect}"

# Тестируем all_email_contacts
email_contacts = user_with_restaurants.all_email_contacts
puts "Email контакты: #{email_contacts.inspect}"

# Тестируем has_restaurants?
has_restaurants = user_with_restaurants.has_restaurants?
puts "Есть рестораны: #{has_restaurants}"
puts

# Показать детали ресторанов и их контактов
puts "=== ДЕТАЛИ РЕСТОРАНОВ И КОНТАКТОВ ==="
user_with_restaurants.restaurants.includes(:notification_contacts).each_with_index do |restaurant, index|
  puts "#{index + 1}. #{restaurant.name}"
  puts "   Platform: #{restaurant.platform}"
  restaurant.notification_contacts.each do |contact|
    puts "   - #{contact.contact_type}: #{contact.contact_value} (#{contact.primary? ? 'Primary' : 'Secondary'})"
  end
  puts
end

puts "=== РЕКОМЕНДАЦИИ ДЛЯ ТЕСТИРОВАНИЯ ==="
puts "1. Откройте браузер: http://localhost:3001/dev/onboarding"
puts "2. Войдите как пользователь ID #{user_with_restaurants.id}"
puts "3. Проверьте, что автозаполнение работает:"
puts "   - WhatsApp: #{whatsapp_contacts.empty? ? 'НЕТ ДАННЫХ' : whatsapp_contacts.join(', ')}"
puts "   - Telegram: #{telegram_contacts.empty? ? 'НЕТ ДАННЫХ' : telegram_contacts.join(', ')}"
puts "   - Email: #{email_contacts.empty? ? 'НЕТ ДАННЫХ' : email_contacts.join(', ')}"
puts "4. Проверьте кнопку 'Clear auto-fill data'"
puts

# Проверим также пользователя без ресторанов
user_without_restaurants = User.left_joins(:restaurants).where(restaurants: { id: nil }).first

if user_without_restaurants
  puts "=== ПОЛЬЗОВАТЕЛЬ БЕЗ РЕСТОРАНОВ (для контроля) ==="
  puts "User ID: #{user_without_restaurants.id}"
  puts "WhatsApp: #{user_without_restaurants.all_whatsapp_contacts.inspect}"
  puts "Telegram: #{user_without_restaurants.all_telegram_contacts.inspect}"  
  puts "Email: #{user_without_restaurants.all_email_contacts.inspect}"
  puts "Has restaurants: #{user_without_restaurants.has_restaurants?}"
else
  puts "ℹ️  Все пользователи имеют рестораны"
end

puts
puts "Тестирование готово! ✅"