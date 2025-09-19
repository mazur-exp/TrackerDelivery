#!/usr/bin/env ruby

require_relative 'app/services/grab_parser_service'

# Test the Grab parser with a sample URL
test_url = "https://food.grab.com/id/en/restaurant/aastha-vegetarian-restaurant-denpasar/IDFOODT81000008KI2"

puts "Testing Grab parser with URL: #{test_url}"
puts "=" * 80

parser = GrabParserService.new
result = parser.parse(test_url)

if result
  puts "SUCCESS! Parsed data:"
  puts "Name: #{result[:name]}"
  puts "Address: #{result[:address]}"
  puts "Cuisines: #{result[:cuisines].inspect}"
  puts "Rating: #{result[:rating]}"
  puts "Working Hours: #{result[:working_hours].inspect}"
  puts "Image URL: #{result[:image_url]}"
else
  puts "FAILED! Parser returned nil"
end
