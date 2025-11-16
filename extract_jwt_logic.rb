# JWT из reqid=176 (из вашего первого скриншота):
# eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnYWEiLCJhdWQiOiJnZnciLCJuYW1lIjoiZ3JhYnRheGkiLCJpYXQiOjE3NjMwOTI3MTIsImV4cCI6MTc2MzA5MzMxMiwibmJmIjoxNzYzMDkyNzEyLCJ2ZXIiOiIxLjE5LjAuMjQiLCJicklEIjoiOGY1OTc0YTFhYjAyZTIwZmMyZTQyZGI3ZjQ2N2Y3ZTZiNTN5NnIiLCJzdXMiOmZhbHNlLCJicklEdjIiOiI1Y2JjZTIzMDgzMmFhMmE1MGM2OWQ5Y2EyZGUyNTRjYzQ3Y3k2ciIsImJyVUlEIjoiOWM2OTZmYWMtODNjYy00MjZmLTgyM2MtZjJkZmJkM2Y3YmEwIn0...

require 'base64'
require 'json'

jwt = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnYWEiLCJhdWQiOiJnZnciLCJuYW1lIjoiZ3JhYnRheGkiLCJpYXQiOjE3NjMwOTI3MTIsImV4cCI6MTc2MzA5MzMxMiwibmJmIjoxNzYzMDkyNzEyLCJ2ZXIiOiIxLjE5LjAuMjQiLCJicklEIjoiOGY1OTc0YTFhYjAyZTIwZmMyZTQyZGI3ZjQ2N2Y3ZTZiNTN5NnIiLCJzdXMiOmZhbHNlLCJicklEdjIiOiI1Y2JjZTIzMDgzMmFhMmE1MGM2OWQ5Y2EyZGUyNTRjYzQ3Y3k2ciIsImJyVUlEIjoiOWM2OTZmYWMtODNjYy00MjZmLTgyM2MtZjJkZmJkM2Y3YmEwIn0"

# Decode JWT parts
parts = jwt.split('.')
header = JSON.parse(Base64.urlsafe_decode64(parts[0]))
payload = JSON.parse(Base64.urlsafe_decode64(parts[1]))

puts "=== JWT Analysis ==="
puts "\nHeader: #{header}"
puts "\nPayload:"
payload.each { |k,v| puts "  #{k}: #{v}" }

puts "\n=== Key Observations ==="
puts "Issuer: #{payload['iss']}"  # gaa
puts "Audience: #{payload['aud']}"  # gfw
puts "brUID: #{payload['brUID']}"  # Browser UID from hwuuid cookie!
puts "Expires in: #{(payload['exp'] - payload['iat']) / 60} minutes"
