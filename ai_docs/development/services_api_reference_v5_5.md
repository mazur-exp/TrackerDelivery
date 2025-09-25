# Services API Reference v5.5

## Overview

TrackerDelivery v5.5 includes 9 core service classes that handle parsing, notifications, localization, geocoding, and system diagnostics. All services are designed for production reliability with comprehensive error handling and logging.

## Service Architecture

### Service Categories

1. **Parser Services** (4 services)
   - GrabParserService
   - GojekParserService  
   - RetryableParser (base class)
   - RestaurantParserService (factory)

2. **Communication Services** (2 services)
   - NotificationService
   - LoopsEmailService

3. **Data Services** (2 services)
   - CuisineTranslationService
   - GeocodingService

4. **System Services** (1 service)
   - ChromeDiagnosticService

## 1. GrabParserService

Production-ready parser for GrabFood platform with 100% reliability through retry mechanisms.

### Class Definition
```ruby
class GrabParserService < RetryableParser
  TIMEOUT_SECONDS = 30
end
```

### Public Methods

#### parse(url)
Main parsing method with full retry support.

**Parameters:**
- `url` (String): GrabFood restaurant URL

**Returns:**
- `Hash`: Complete restaurant data
- `nil`: If parsing fails

**Example:**
```ruby
service = GrabParserService.new
data = service.parse("https://food.grab.com/id/en/restaurant/example")

# Returns:
{
  name: "Restaurant Name",
  address: "Full Address", 
  rating: "4.5",
  cuisines: ["Indonesian", "Grilled"],
  coordinates: { latitude: -6.123456, longitude: 106.789012 },
  status: { is_open: true, status_text: "open", error: nil },
  working_hours: [
    { day: "monday", open_time: "10:00", close_time: "22:00" }
  ],
  images: ["https://..."]
}
```

#### check_status_only(url)
Quick status check for monitoring.

**Parameters:**
- `url` (String): Restaurant URL

**Returns:**
- `Hash`: Status information only

**Example:**
```ruby
status = service.check_status_only(url)
# Returns: { is_open: true, status_text: "open", error: nil }
```

### Key Features
- **Timeout**: 30 seconds with production optimizations
- **JSON Extraction**: Primary data source (faster)
- **DOM Fallback**: Secondary extraction method
- **Chrome Auto-Detection**: Works with Chrome/Chromium
- **Performance**: ~5.87s average, 100% success rate

---

## 2. GojekParserService

Advanced parser for GoFood platform with Indonesian localization and modal interaction.

### Class Definition
```ruby
class GojekParserService < RetryableParser
  TIMEOUT_SECONDS = 60  # Extended for production servers
end
```

### Public Methods

#### parse(url)
Main parsing with modal interaction and localization.

**Parameters:**
- `url` (String): GoFood restaurant URL

**Returns:**
- `Hash`: Complete restaurant data with translated cuisines

**Example:**
```ruby
service = GojekParserService.new
data = service.parse("https://gofood.co.id/jakarta/restaurant/example")

# Returns:
{
  name: "Warung Padang",
  address: "Jakarta Address",
  rating: "4.3",  # May be "NEW" for new restaurants
  cuisines: ["Padang", "Indonesian"],  # Translated to English
  working_hours: [...],
  image_url: "https://...",
  status: { is_open: true, status_text: "open" }
}
```

#### check_status_only(url)
Optimized status check (15s timeout).

### Key Features
- **Extended Timeout**: 60s for slow production servers
- **Modal Interaction**: Clicks info buttons for complete data
- **Cuisine Translation**: Indonesian → English via CuisineTranslationService
- **Performance Monitoring**: Detailed timing logs
- **Production Optimizations**: Disabled images, cache optimizations

---

## 3. RetryableParser

Base class providing enterprise-grade reliability for all parsers.

### Class Definition
```ruby
class RetryableParser
  RETRY_DELAYS = [2, 4, 8].freeze
  MAX_RETRIES = 3
  CIRCUIT_BREAKER_THRESHOLD = 5
  CIRCUIT_BREAKER_RESET_TIME = 30
end
```

### Public Methods

#### parse_with_retry(url)
Core retry mechanism with circuit breaker protection.

**Parameters:**
- `url` (String): URL to parse

**Returns:**
- `Hash`: Parsed data if successful
- `nil`: If all retry attempts fail or circuit breaker is open

**Retry Logic:**
1. Check circuit breaker status
2. Attempt parsing (up to 3 tries)
3. Apply exponential backoff (2s → 4s → 8s)
4. Clean up resources between attempts
5. Update circuit breaker state

### Error Classification

**Recoverable Errors (trigger retry):**
- `Selenium::WebDriver::Error::InvalidSessionIdError`
- `Selenium::WebDriver::Error::WebDriverError`
- `Selenium::WebDriver::Error::SessionNotCreatedError`
- `Timeout::Error`
- Network connectivity issues

**Non-Recoverable Errors (immediate failure):**
- `Selenium::WebDriver::Error::NoSuchElementError`
- `Selenium::WebDriver::Error::InvalidArgumentError`
- `ArgumentError`
- `URI::InvalidURIError`

### Circuit Breaker Features
- **Failure Threshold**: 5 failures before opening
- **Reset Time**: 30 seconds in open state
- **Automatic Recovery**: Resets on successful operations
- **Per-Service State**: Each parser service has its own circuit breaker

---

## 4. RestaurantParserService

Factory service for selecting appropriate parser based on platform.

### Class Definition
```ruby
class RestaurantParserService
end
```

### Public Methods

#### self.parse(restaurant_or_url)
Factory method that selects correct parser.

**Parameters:**
- `restaurant_or_url` (Restaurant|String): Restaurant model or platform URL

**Returns:**
- `Hash`: Parsed restaurant data

**Example:**
```ruby
# With restaurant model
restaurant = Restaurant.find(1)  # platform: "grab"
data = RestaurantParserService.parse(restaurant)

# With URL (auto-detects platform)
data = RestaurantParserService.parse("https://food.grab.com/...")
```

### Implementation Logic
```ruby
def self.parse(restaurant_or_url)
  if restaurant_or_url.is_a?(Restaurant)
    case restaurant_or_url.platform
    when "grab"
      GrabParserService.new.parse(restaurant_or_url.platform_url)
    when "gojek" 
      GojekParserService.new.parse(restaurant_or_url.platform_url)
    else
      raise ArgumentError, "Unknown platform: #{restaurant_or_url.platform}"
    end
  elsif restaurant_or_url.is_a?(String)
    # Auto-detect platform from URL
    if restaurant_or_url.match?(/grab\.com|grabfood/i)
      GrabParserService.new.parse(restaurant_or_url)
    elsif restaurant_or_url.match?(/gofood|gojek/i)
      GojekParserService.new.parse(restaurant_or_url)
    else
      raise ArgumentError, "Cannot determine platform from URL: #{restaurant_or_url}"
    end
  end
end
```

---

## 5. NotificationService

Multi-channel notification system supporting Telegram, WhatsApp, and Email alerts.

### Class Definition
```ruby
class NotificationService
end
```

### Public Methods

#### send_restaurant_anomaly_alert(restaurant, status_check)
Sends anomaly alerts through all configured channels.

**Parameters:**
- `restaurant` (Restaurant): Restaurant model
- `status_check` (RestaurantStatusCheck): Status check record

**Example:**
```ruby
service = NotificationService.new
service.send_restaurant_anomaly_alert(restaurant, status_check)
```

**Notification Channels:**
- **Telegram**: Instant message to configured chats
- **WhatsApp**: SMS-style alert to phone numbers  
- **Email**: Detailed HTML email via LoopsEmailService

#### send_monitoring_summary(results, duration)
Sends monitoring job summary reports.

**Parameters:**
- `results` (Hash): Monitoring job results
- `duration` (Float): Execution time in seconds

**Example:**
```ruby
results = {
  total: 15,
  checked: 14, 
  anomalies: 3,
  errors: 1
}
service.send_monitoring_summary(results, 67.5)
```

### Notification Content Examples

**Anomaly Alert:**
```
🚨 Restaurant Status Alert

Restaurant: Warung Nasi Gudeg
Platform: GrabFood  
Expected: OPEN
Actual: CLOSED
Time: 2025-01-15 14:30 UTC

This may indicate a revenue-impacting issue.
Check: https://food.grab.com/...
```

**Summary Report:**
```
📊 Monitoring Summary - 14:35 UTC

✅ Restaurants Checked: 14/15
🚨 Anomalies Found: 3  
⚠️ Errors: 1
⏱️ Execution Time: 67.5s

Affected Restaurants:
- Warung A: Expected OPEN, got CLOSED
- Restaurant B: Expected CLOSED, got OPEN
- Cafe C: Parser timeout error
```

### Configuration
```ruby
# Environment variables
ENV['TELEGRAM_BOT_TOKEN'] = 'your_bot_token'
ENV['WHATSAPP_API_KEY'] = 'your_api_key'
ENV['LOOPS_API_KEY'] = 'your_loops_key'

# Enable/disable channels
ENV['TELEGRAM_ALERTS_ENABLED'] = 'true'
ENV['WHATSAPP_ALERTS_ENABLED'] = 'true' 
ENV['EMAIL_ALERTS_ENABLED'] = 'true'
```

---

## 6. LoopsEmailService

Email delivery service integrated with Loops.so for transactional emails.

### Class Definition
```ruby
class LoopsEmailService
end
```

### Public Methods

#### send_transactional(email_address, template_id, data_variables)
Sends transactional emails via Loops API.

**Parameters:**
- `email_address` (String): Recipient email
- `template_id` (String): Loops template ID
- `data_variables` (Hash): Template variables

**Returns:**
- `Hash`: API response

**Example:**
```ruby
service = LoopsEmailService.new
response = service.send_transactional(
  "user@example.com",
  "restaurant_anomaly_alert",
  {
    restaurant_name: "Warung Nasi Gudeg",
    expected_status: "open",
    actual_status: "closed",
    platform: "GrabFood",
    alert_time: "14:30 UTC",
    platform_url: "https://food.grab.com/..."
  }
)
```

#### send_welcome_email(user)
Sends welcome email to new users.

#### send_email_confirmation(user)
Sends email confirmation for account verification.

### API Integration
```ruby
# Loops.so API configuration
LOOPS_API_BASE = "https://app.loops.so/api/v1"
LOOPS_API_KEY = ENV['LOOPS_API_KEY']

# Headers
{
  "Authorization": "Bearer #{LOOPS_API_KEY}",
  "Content-Type": "application/json"
}
```

### Email Templates
- `restaurant_anomaly_alert` - Status anomaly notifications
- `monitoring_summary` - Daily/hourly monitoring reports
- `welcome_email` - New user welcome
- `email_confirmation` - Account verification
- `password_reset` - Password reset instructions

---

## 7. CuisineTranslationService

Indonesian to English cuisine translation for international users.

### Class Definition  
```ruby
class CuisineTranslationService
end
```

### Class Methods

#### self.translate(indonesian_text)
Translates Indonesian cuisine names to English.

**Parameters:**
- `indonesian_text` (String): Indonesian cuisine name

**Returns:**
- `String`: English translation or original text if no translation found

**Examples:**
```ruby
CuisineTranslationService.translate("Makanan Indonesia")  # => "Indonesian"
CuisineTranslationService.translate("Makanan Padang")     # => "Padang"
CuisineTranslationService.translate("Minuman")            # => "Beverages"
CuisineTranslationService.translate("Unknown Cuisine")    # => "Unknown Cuisine"
```

#### self.translate_array(cuisines_array)
Translates array of cuisine names.

**Parameters:**
- `cuisines_array` (Array): Array of Indonesian cuisine names

**Returns:**
- `Array`: Array of translated cuisine names

**Example:**
```ruby
cuisines = ["Makanan Indonesia", "Minuman", "Makanan Padang"]
translated = CuisineTranslationService.translate_array(cuisines)
# => ["Indonesian", "Beverages", "Padang"]
```

### Translation Database
Uses `cuisine_translations` table for accurate mappings:

```ruby
# Common translations stored in database
{
  "Makanan Indonesia" => "Indonesian",
  "Makanan Padang" => "Padang", 
  "Makanan Jawa" => "Javanese",
  "Makanan Betawi" => "Betawi",
  "Makanan Batak" => "Batak",
  "Makanan Sunda" => "Sundanese",
  "Minuman" => "Beverages",
  "Makanan Penutup" => "Desserts",
  "Makanan Ringan" => "Snacks"
}
```

### Fallback Logic
1. **Exact Match**: Check database for exact translation
2. **Partial Match**: Pattern matching for common terms
3. **Default**: Return original text if no translation found

---

## 8. GeocodingService

Address coordinate resolution service for restaurant locations.

### Class Definition
```ruby
class GeocodingService
end
```

### Public Methods

#### geocode(address)
Converts address string to latitude/longitude coordinates.

**Parameters:**
- `address` (String): Address to geocode

**Returns:**
- `Hash`: Coordinates hash or nil if geocoding fails

**Example:**
```ruby
service = GeocodingService.new
coords = service.geocode("Jl. Malioboro No.123, Yogyakarta, Indonesia")

# Returns:
{
  latitude: -7.795580,
  longitude: 110.369492,
  formatted_address: "Jl. Malioboro No.123, Yogyakarta City, Special Region of Yogyakarta, Indonesia"
}
```

#### reverse_geocode(latitude, longitude)  
Converts coordinates to formatted address.

**Parameters:**
- `latitude` (Float): Latitude coordinate
- `longitude` (Float): Longitude coordinate

**Returns:**
- `String`: Formatted address

### Service Integration
Can integrate with multiple geocoding providers:

1. **Google Geocoding API** (primary)
2. **OpenStreetMap Nominatim** (fallback)
3. **MapBox Geocoding** (alternative)

### Configuration
```ruby
# Google Maps API
ENV['GOOGLE_MAPS_API_KEY'] = 'your_api_key'

# Rate limiting
GEOCODING_RATE_LIMIT = 10  # requests per second
GEOCODING_CACHE_TTL = 86400  # 24 hours
```

### Error Handling
```ruby
def geocode(address)
  return nil if address.blank?
  
  begin
    # Try primary service (Google)
    result = google_geocode(address)
    return result if result
    
    # Fallback to Nominatim
    nominatim_geocode(address)
  rescue => e
    Rails.logger.error "Geocoding failed for '#{address}': #{e.message}"
    nil
  end
end
```

---

## 9. ChromeDiagnosticService

System diagnostic service for Chrome/ChromeDriver troubleshooting in production.

### Class Definition
```ruby
class ChromeDiagnosticService
end
```

### Public Methods

#### self.system_check
Comprehensive system diagnostic check.

**Returns:**
- `Hash`: System diagnostic results

**Example:**
```ruby
diagnostics = ChromeDiagnosticService.system_check

# Returns:
{
  chrome_binary: {
    found: true,
    path: "/usr/bin/google-chrome",
    version: "120.0.6099.109"
  },
  chromedriver: {
    found: true,
    path: "/usr/local/bin/chromedriver",
    version: "120.0.6099.71"
  },
  compatibility: {
    versions_match: true,
    status: "compatible"
  },
  system: {
    os: "linux",
    architecture: "x86_64",
    memory_available: "2048 MB"
  },
  parser_test: {
    grab_parser: "functional",
    gojek_parser: "functional",
    test_duration: 12.34
  }
}
```

#### self.test_parser(parser_class)
Tests specific parser functionality.

**Parameters:**
- `parser_class` (Class): Parser class to test

**Returns:**
- `Hash`: Test results

#### self.chrome_version
Returns Chrome browser version.

#### self.chromedriver_version
Returns ChromeDriver version.

### Diagnostic Categories

1. **Binary Detection**
   - Chrome/Chromium binary location
   - ChromeDriver location
   - Version extraction

2. **Version Compatibility**
   - Chrome/ChromeDriver version matching
   - Supported version ranges
   - Compatibility warnings

3. **System Resources**
   - Available memory
   - CPU architecture
   - Operating system details

4. **Parser Functionality** 
   - Test parsing with sample URLs
   - Measure performance
   - Detect configuration issues

### Usage in Production
```ruby
# Health check endpoint
def health_check
  diagnostics = ChromeDiagnosticService.system_check
  
  if diagnostics[:compatibility][:status] == "compatible"
    render json: { status: "healthy", diagnostics: diagnostics }
  else
    render json: { status: "unhealthy", diagnostics: diagnostics }, status: 503
  end
end
```

## Service Integration Examples

### Restaurant Monitoring Workflow
```ruby
class RestaurantMonitoringJob
  def check_restaurant_status(restaurant)
    # 1. Parse restaurant data
    parser_service = RestaurantParserService.new
    full_data = parser_service.parse(restaurant)
    
    # 2. Translate cuisines if needed
    if restaurant.gojek? && full_data[:cuisines]
      full_data[:cuisines] = CuisineTranslationService.translate_array(full_data[:cuisines])
    end
    
    # 3. Geocode address if missing coordinates
    if full_data[:address] && restaurant.coordinates.blank?
      coords = GeocodingService.new.geocode(full_data[:address])
      restaurant.set_coordinates(coords[:latitude], coords[:longitude]) if coords
    end
    
    # 4. Check for anomalies
    is_anomaly = detect_anomaly(restaurant, full_data[:status])
    
    # 5. Send notifications if anomaly detected
    if is_anomaly
      status_check = record_status_check(restaurant, full_data, is_anomaly)
      NotificationService.new.send_restaurant_anomaly_alert(restaurant, status_check)
    end
  end
end
```

### User Onboarding Workflow
```ruby
class RestaurantsController < ApplicationController
  def create
    restaurant = current_user.restaurants.build(restaurant_params)
    
    if restaurant.save
      # 1. Parse initial restaurant data
      full_data = RestaurantParserService.parse(restaurant)
      
      # 2. Update restaurant with parsed data
      if full_data
        restaurant.update!(
          name: full_data[:name] || restaurant.name,
          address: full_data[:address],
          rating: full_data[:rating],
          cuisine_primary: full_data[:cuisines]&.first
        )
        
        # 3. Geocode address
        if full_data[:address]
          coords = GeocodingService.new.geocode(full_data[:address])
          restaurant.set_coordinates(coords[:latitude], coords[:longitude]) if coords
        end
        
        # 4. Send welcome email
        LoopsEmailService.new.send_transactional(
          current_user.email_address,
          "restaurant_onboarded",
          {
            user_name: current_user.name,
            restaurant_name: restaurant.name,
            platform: restaurant.platform.humanize
          }
        )
      end
      
      redirect_to dashboard_path, notice: "Restaurant added successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end
end
```

### System Health Monitoring
```ruby
class HealthController < ApplicationController
  def system_status
    # 1. Check parser system health
    diagnostics = ChromeDiagnosticService.system_check
    
    # 2. Check circuit breaker status
    circuit_breaker_status = {
      grab_parser: {
        failures: GrabParserService.circuit_breaker_failures,
        open: GrabParserService.new.send(:circuit_breaker_open?)
      },
      gojek_parser: {
        failures: GojekParserService.circuit_breaker_failures,
        open: GojekParserService.new.send(:circuit_breaker_open?)
      }
    }
    
    # 3. Check recent monitoring job performance
    recent_checks = RestaurantStatusCheck.where("checked_at > ?", 1.hour.ago)
    monitoring_health = {
      total_checks: recent_checks.count,
      error_rate: recent_checks.where(actual_status: "error").count.to_f / recent_checks.count,
      last_successful_check: recent_checks.where.not(actual_status: "error").maximum(:checked_at)
    }
    
    render json: {
      system_diagnostics: diagnostics,
      circuit_breakers: circuit_breaker_status,
      monitoring_health: monitoring_health,
      timestamp: Time.current
    }
  end
end
```

This comprehensive API reference provides detailed documentation for all 9 service classes in TrackerDelivery v5.5, enabling effective integration and troubleshooting in production environments.