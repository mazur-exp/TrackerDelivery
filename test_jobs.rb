puts '=== СТАТУС ДЖОБСОВ ПОСЛЕ ПЕРЕЗАПУСКА ==='
puts

puts 'Тестируем метод expected_status_at:'
r = Restaurant.first
if r
  puts "Ресторан: #{r.name}"
  begin
    puts "Ожидаемый статус сейчас: #{r.expected_status_at}"
  rescue => e
    puts "ОШИБКА: #{e.message}"
  end
else
  puts "Нет ресторанов в базе"
end

puts
puts 'Последние 3 новые проверки:'
RestaurantStatusCheck.order(checked_at: :desc).limit(3).each do |check|
  restaurant_name = check.restaurant.name rescue "Restaurant #{check.restaurant_id}"
  puts "#{check.checked_at.strftime('%H:%M:%S')} - #{restaurant_name}: #{check.expected_status} -> #{check.actual_status}"
end

puts
puts 'Статистика джобсов за последние 30 минут:'
recent = RestaurantStatusCheck.where('checked_at > ?', 30.minutes.ago)
puts "- Всего проверок: #{recent.count}"
puts "- Успешные: #{recent.where.not(actual_status: 'error').count}"
puts "- Ошибки: #{recent.where(actual_status: 'error').count}"
puts "- Аномалии: #{recent.where(is_anomaly: true).count}"