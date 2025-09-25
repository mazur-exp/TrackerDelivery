#!/usr/bin/env ruby
require_relative "config/environment"

puts "=== DEBUG USER CONTACTS ==="

user = User.find(1)
puts "User ID: #{user.id}"
puts "Has restaurants: #{user.has_restaurants?}"
puts "Restaurants count: #{user.restaurants.count}"
puts

# Debug notification contacts
puts "=== ALL NOTIFICATION CONTACTS ==="
user.restaurants.each do |restaurant|
  puts "Restaurant: #{restaurant.name}"
  restaurant.notification_contacts.each do |contact|
    puts "  #{contact.contact_type}: #{contact.contact_value} (active: #{contact.is_active}, primary: #{contact.is_primary})"
  end
  puts
end

puts "=== AUTO-FILL METHODS ==="
whatsapp = user.all_whatsapp_contacts
telegram = user.all_telegram_contacts  
email = user.all_email_contacts

puts "all_whatsapp_contacts: #{whatsapp.inspect}"
puts "all_telegram_contacts: #{telegram.inspect}"
puts "all_email_contacts: #{email.inspect}"
puts

puts "=== CHECKING is_active FILTER ==="
# Test without is_active filter
all_whatsapp_raw = user.restaurants.joins(:notification_contacts)
                      .where(notification_contacts: { contact_type: "whatsapp" })
                      .pluck("notification_contacts.contact_value", "notification_contacts.is_active")

puts "All WhatsApp (without is_active filter): #{all_whatsapp_raw.inspect}"

# Test counts
whatsapp_count = user.restaurants.joins(:notification_contacts)
                    .where(notification_contacts: { contact_type: "whatsapp", is_active: true })
                    .count

puts "Active WhatsApp count: #{whatsapp_count}"
puts "Total notification_contacts: #{NotificationContact.count}"