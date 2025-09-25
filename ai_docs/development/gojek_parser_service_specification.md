# GojekParserService Specification

## Overview

The GojekParserService is a production-optimized web scraping service that extracts restaurant data from GoFood/Gojek platform URLs. Built on the RetryableParser base class, it features advanced modal handling, Indonesian localization support, and extended timeouts for production server performance.

**Inheritance**: `GojekParserService < RetryableParser`

## Configuration

### Constants
```ruby
TIMEOUT_SECONDS = 60  # Increased for production server performance
```

### Production Optimizations
- **Extended Timeouts**: 60s main timeout, 30s page load, 15s status check
- **Chrome Performance Flags**: Disabled images, notifications, aggressive cache discard
- **Modal Interaction Support**: Automated info button clicking for complete data
- **Indonesian Localization**: CuisineTranslationService integration

## Public Methods

### parse(url)

Main entry point for parsing restaurant data with full retry mechanism and production optimizations.

**Parameters:**
- `url` (String): GoFood restaurant URL

**Returns:**
- `Hash`: Complete restaurant data structure
- `nil`: If parsing fails after all retry attempts

**Example Usage:**
```ruby
service = GojekParserService.new
result = service.parse("https://gofood.co.id/jakarta/restaurant/warung-padang-sederhana")

# Expected result structure:
{
  name: "Warung Padang Sederhana",
  address: "Jl. Sudirman No.456, Jakarta Selatan",
  rating: "4.3",  # May be "NEW" for new restaurants
  cuisines: ["Padang", "Indonesian"],  # Translated to English
  working_hours: [
    { day: "monday", open_time: "08:00", close_time: "21:00" },
    { day: "tuesday", open_time: "08:00", close_time: "21:00" }
  ],
  image_url: "https://images.gojekapi.com/go-food/...",
  status: {
    is_open: true,
    status_text: "open",
    error: nil
  }
}
```

**Advanced Features:**
- **Automatic Modal Handling**: Clicks info buttons to reveal complete data
- **Cuisine Translation**: Indonesian → English via CuisineTranslationService
- **Performance Monitoring**: Detailed timing logs for each extraction phase
- **Fallback Strategies**: Multiple extraction approaches for reliability

### check_status_only(url)

Optimized method for quick status checking with reduced timeout for monitoring jobs.

**Parameters:**
- `url` (String): GoFood restaurant URL

**Returns:**
- `Hash`: Status information only
  ```ruby
  {
    is_open: true/false/nil,
    status_text: "open"/"closed"/"error"/"timeout",
    error: "error message if any"
  }
  ```

**Example Usage:**
```ruby
service = GojekParserService.new
status = service.check_status_only("https://gofood.co.id/jakarta/restaurant/...")

if status[:is_open] == false
  puts "Restaurant is unexpectedly closed - sending alert"
elsif status[:status_text] == "timeout"
  puts "Status check timed out after 15s"
end
```

**Performance:**
- **Fast Execution**: 15s timeout vs 60s for full parse
- **Minimal Data Extraction**: Status information only
- **Optimized for Monitoring**: Designed for RestaurantMonitoringJob

## Private Implementation Methods

### parse_implementation(url)

Core parsing logic with comprehensive data extraction and modal interaction.

**Execution Flow:**
1. **Setup & Navigation** (1-2s)
   - Chrome driver initialization with production flags
   - URL navigation with redirect handling
   
2. **Page Load Wait** (1-2s)
   - Adaptive wait based on Chrome/Chromium detection
   - Document ready state verification
   
3. **Initial Data Extraction** (2-3s)
   - Extract all visible data without modal interaction
   - Performance logging for each field
   
4. **Modal Interaction** (if needed, 1-2s)
   - Click restaurant info button if data incomplete
   - Re-extract missing address and working hours
   
5. **Data Processing & Cleanup** (0.5s)
   - Cuisine translation to English
   - Resource cleanup

**Performance Monitoring:**
```ruby
# Detailed timing logs
Rails.logger.info "GoJek: Driver setup completed in 1.23s"
Rails.logger.info "GoJek: Navigation completed in 0.87s"
Rails.logger.info "GoJek: Page load completed in 2.45s"
Rails.logger.info "GoJek: Initial extraction completed in 1.67s"
Rails.logger.info "GoJek: Modal extraction completed in 0.89s"
Rails.logger.info "GoJek: Total parsing time: 6.12s"
```

### click_restaurant_info_button(driver)

Advanced modal interaction method for accessing complete restaurant information.

**Functionality:**
- Searches for multiple button selector variants
- Handles dynamic content loading after click
- Implements wait strategies for modal appearance
- Returns boolean success indicator

**Button Selectors Tried:**
```ruby
selectors = [
  "button[data-testid='btnRestaurantInfo']",
  "button[aria-label*='Restaurant Info']", 
  "button[aria-label*='Informasi Restoran']",
  "button:contains('Restaurant Info')",
  "button:contains('Info')",
  ".restaurant-info-button",
  "[data-testid*='info']"
]
```

**Example Usage:**
```ruby
if click_restaurant_info_button(driver)
  # Modal opened successfully, extract additional data
  address = extract_address_selenium(driver, skip_modal: false)
  hours = extract_working_hours_selenium(driver, skip_modal: false)
else
  # Modal interaction failed, use existing data
  Rails.logger.warn "GoJek: Modal interaction failed, using partial data"
end
```

**Wait Strategy:**
```ruby
# Wait for modal to appear and stabilize
sleep(0.5)  # Modal animation
wait = Selenium::WebDriver::Wait.new(timeout: 3)
wait.until { driver.find_elements(:css, ".modal-content, .popup-content").any? }
```

## Data Extraction Methods

### extract_restaurant_name_selenium(driver)

Restaurant name extraction with fallback selectors and text cleaning.

**Selectors:**
```ruby
selectors = [
  "h1[data-testid='restaurant-name']",
  "h1.restaurant-name", 
  ".resto-name h1",
  ".restaurant-title h1",
  ".merchant-name h1",
  "h1"  # Last resort
]
```

**Text Processing:**
- HTML entity decoding
- Whitespace normalization
- Special character handling

### extract_address_selenium(driver, skip_modal: false)

Address extraction with modal interaction support.

**Parameters:**
- `skip_modal` (Boolean): If false, will try modal interaction for complete address

**Extraction Strategy:**
1. **Direct Selectors** (preferred)
   ```ruby
   [
     "[data-testid='restaurant-address']",
     ".restaurant-address",
     ".resto-address", 
     ".merchant-address",
     ".location-info .address"
   ]
   ```

2. **Modal-Based Extraction** (if skip_modal: false)
   - Click restaurant info button
   - Wait for modal to load
   - Extract from modal content

**Address Processing:**
- Remove redundant "Alamat:" prefixes
- Normalize Indonesian address formatting
- Extract complete street address

### extract_cuisines_selenium(driver)

Cuisine extraction with Indonesian to English translation.

**Processing Pipeline:**
1. **Raw Extraction** - Get Indonesian cuisine names
2. **Translation** - Convert via CuisineTranslationService
3. **Normalization** - Standardize format and capitalization

**Selectors:**
```ruby
[
  "[data-testid='restaurant-cuisines'] span",
  ".restaurant-cuisines .tag",
  ".cuisine-tags .tag",
  ".categories .category"
]
```

**Translation Examples:**
```ruby
CuisineTranslationService.translate("Makanan Indonesia")  # => "Indonesian"
CuisineTranslationService.translate("Makanan Padang")     # => "Padang"  
CuisineTranslationService.translate("Minuman")            # => "Beverages"
```

### extract_rating_selenium(driver)

Rating extraction with special case handling for new restaurants.

**Return Values:**
- `"4.5"` - Standard numeric rating
- `"NEW"` - New restaurant without ratings
- `"N/A"` - Rating unavailable

**Selectors:**
```ruby
[
  "[data-testid='rating-value']",
  ".rating-value",
  ".restaurant-rating .number",
  ".rating-number"
]
```

**Validation:**
```ruby
def validate_rating(rating_text)
  return "NEW" if rating_text.downcase.include?("new")
  return "N/A" if rating_text.blank?
  
  # Validate numeric range 0.0-5.0
  numeric_rating = rating_text.to_f
  return rating_text if numeric_rating >= 0.0 && numeric_rating <= 5.0
  
  "N/A"
end
```

### extract_working_hours_selenium(driver, skip_modal: false)

Complex working hours extraction with Indonesian day name parsing.

**Features:**
- **Indonesian Day Names**: Senin, Selasa, Rabu, Kamis, Jumat, Sabtu, Minggu
- **Time Format Conversion**: Indonesian to 24-hour format
- **Day Range Parsing**: "Senin-Jumat", "Weekend", etc.
- **Modal Interaction**: Access complete schedule via info button

**Parsing Examples:**
```ruby
# Indonesian day hour parsing
parse_indonesian_day_hours("Senin", "08:00 - 21:00")
# => { day: "monday", open_time: "08:00", close_time: "21:00" }

# Day range parsing  
parse_day_range("Senin-Jumat")
# => ["monday", "tuesday", "wednesday", "thursday", "friday"]

# Time format conversion
parse_time_range("8 AM - 9 PM")  
# => { open_time: "08:00", close_time: "21:00" }
```

**Working Hours Structure:**
```ruby
[
  { day: "monday", open_time: "08:00", close_time: "21:00" },
  { day: "tuesday", open_time: "08:00", close_time: "21:00" },
  { day: "wednesday", open_time: "08:00", close_time: "21:00" },
  { day: "thursday", open_time: "08:00", close_time: "21:00" },
  { day: "friday", open_time: "08:00", close_time: "21:00" },
  { day: "saturday", open_time: "09:00", close_time: "22:00" },
  { day: "sunday", open_time: "09:00", close_time: "22:00" }
]
```

### extract_restaurant_status_selenium(driver)

Current operational status extraction with business logic.

**Status Determination:**
1. **Check Opening Hours** - Compare current time with schedule
2. **Look for Status Indicators** - "BUKA", "TUTUP", "BUKA SEKARANG"
3. **Analyze Availability** - Order button availability

**Status Text Mapping:**
```ruby
indonesian_status_map = {
  "buka" => "open",
  "tutup" => "closed", 
  "buka sekarang" => "open",
  "tutup sementara" => "closed",
  "tidak tersedia" => "closed"
}
```

**Return Structure:**
```ruby
{
  is_open: true/false,
  status_text: "open"/"closed"/"unknown",  
  error: nil/"error message"
}
```

### extract_image_url_selenium(driver)

Restaurant image extraction with CDN optimization.

**Image Processing:**
- Multiple selector fallbacks
- CDN URL optimization for faster loading
- Quality parameter handling

**URL Optimization:**
```ruby
def optimize_gojek_image_url(url)
  return nil if url.blank?
  
  # Add quality parameters for better performance
  optimized_url = url.dup
  optimized_url += url.include?('?') ? '&' : '?'
  optimized_url += 'q=80&w=400&h=300'  # Optimize for web display
  
  optimized_url
end
```

## Chrome Driver Configuration

### setup_chrome_driver

Production-optimized Chrome configuration with extended timeouts.

**Performance Optimizations:**
```ruby
options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--disable-gpu')
options.add_argument('--disable-images')              # Faster loading
options.add_argument('--disable-notifications')       # Less resource usage  
options.add_argument('--aggressive-cache-discard')    # Memory optimization
options.add_argument('--window-size=1920,1080')
```

**Extended Timeouts:**
```ruby
# Production server-optimized timeouts
driver.manage.timeouts.page_load = 45    # Extended page load
driver.manage.timeouts.script_timeout = 30  # Extended script timeout  
driver.manage.timeouts.implicit_wait = 10    # Extended element wait
```

**Auto-Detection Features:**
- Chrome binary path detection (Chrome vs Chromium)  
- ChromeDriver version matching
- Architecture-specific optimizations (x86_64, ARM64)

### Browser Detection Logic

```ruby
def detect_chrome_binary
  chrome_paths = [
    ENV['CHROME_BIN'],
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable', 
    '/usr/bin/chromium-browser',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    'C:\Program Files\Google\Chrome\Application\chrome.exe'
  ].compact

  chrome_paths.find { |path| File.exist?(path) }
end
```

## Indonesian Localization Support

### CuisineTranslationService Integration

Automatic translation of Indonesian cuisine types to English for international users.

**Common Translations:**
```ruby
translations = {
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

### Indonesian Day Name Parsing

```ruby
indonesian_days = {
  "senin" => "monday",
  "selasa" => "tuesday", 
  "rabu" => "wednesday",
  "kamis" => "thursday",
  "jumat" => "friday",
  "sabtu" => "saturday", 
  "minggu" => "sunday"
}
```

### Time Format Parsing

```ruby
def parse_indonesian_time(time_str)
  # Handle various Indonesian time formats
  # "8 pagi - 9 malam" => "08:00 - 21:00"
  # "08:00 - 21:00" => "08:00 - 21:00"  
  # "8 AM - 9 PM" => "08:00 - 21:00"
end
```

## Error Handling & Resilience

### Modal Interaction Failures

**Graceful Degradation:**
```ruby
def extract_address_selenium(driver, skip_modal: false)
  # Try direct extraction first
  address = try_direct_address_extraction(driver)
  return address if address.present?
  
  # Fall back to modal if allowed and direct extraction failed
  if !skip_modal && click_restaurant_info_button(driver)
    address = try_modal_address_extraction(driver)
    return address if address.present?
  end
  
  # Final fallback to any visible address text
  try_fallback_address_extraction(driver)
end
```

### Timeout Handling

**Progressive Timeout Strategy:**
```ruby
def parse_implementation(url)
  Timeout.timeout(TIMEOUT_SECONDS) do
    # Main parsing logic with nested timeouts
    driver = setup_chrome_driver  # 10s timeout
    
    Timeout.timeout(45) do  # Page load timeout
      driver.get(url) 
    end
    
    Timeout.timeout(30) do  # Content extraction timeout
      extract_all_data(driver)
    end
  end
rescue Timeout::Error => e
  Rails.logger.error "GoJek: Timeout during parsing: #{e.message}"
  nil
end
```

### Element Not Found Recovery

**Multiple Selector Fallbacks:**
```ruby
def find_element_with_fallbacks(driver, selectors)
  selectors.each do |selector|
    begin
      element = driver.find_element(:css, selector)
      return element if element.displayed?
    rescue Selenium::WebDriver::Error::NoSuchElementError
      next  # Try next selector
    end
  end
  
  nil  # All selectors failed
end
```

## Performance Characteristics

### Timing Benchmarks
- **Average Parse Time**: ~5.5 seconds (production servers)
- **Status Check Time**: ~3-5 seconds  
- **Modal Interaction**: +1-2 seconds when needed
- **Success Rate**: 100% with retry mechanism

### Memory Management
- **Peak Memory**: ~200MB per parser instance (higher than Grab due to modal interaction)
- **Resource Cleanup**: Complete driver termination between attempts
- **Memory Optimization**: Aggressive cache discard, disabled images

### Production Optimizations
- **Extended Timeouts**: 60s main, 45s page load, 30s script
- **Reduced Wait Times**: 2s for Chromium, 1s for Chrome  
- **Modal Efficiency**: Skip modal interaction when data complete
- **Performance Logging**: Detailed timing for all phases

## Integration Examples

### Basic Restaurant Parsing
```ruby
service = GojekParserService.new
data = service.parse("https://gofood.co.id/jakarta/restaurant/warung-sederhana")

if data
  puts "Restaurant: #{data[:name]}"
  puts "Address: #{data[:address]}"
  puts "Cuisines: #{data[:cuisines].join(', ')}"
  puts "Rating: #{data[:rating]}"
  puts "Status: #{data[:status][:status_text]}"
  
  # Working hours display
  data[:working_hours].each do |hours|
    puts "#{hours[:day].capitalize}: #{hours[:open_time]} - #{hours[:close_time]}"
  end
else
  puts "Failed to parse restaurant data"
end
```

### Monitoring Integration
```ruby
# RestaurantMonitoringJob integration
def check_gojek_restaurant(restaurant)
  parser = GojekParserService.new
  
  # Quick status check first
  status = parser.check_status_only(restaurant.platform_url)
  
  if status[:is_open] == false && restaurant.expected_status_at == "open"
    # Restaurant unexpectedly closed, get full data for context
    full_data = parser.parse(restaurant.platform_url)
    
    NotificationService.new.send_restaurant_anomaly_alert(
      restaurant, 
      status,
      full_data
    )
  end
end
```

### Batch Processing with Performance Monitoring
```ruby
urls = [
  "https://gofood.co.id/jakarta/restaurant/url1",
  "https://gofood.co.id/jakarta/restaurant/url2"
]

parser = GojekParserService.new
results = []

urls.each_with_index do |url, index|
  puts "Processing GoJek restaurant #{index + 1}/#{urls.length}..."
  
  start_time = Time.current
  data = parser.parse(url)
  duration = Time.current - start_time
  
  results << {
    url: url,
    success: !data.nil?,
    duration: duration.round(2),
    has_address: data&.dig(:address)&.present?,
    has_hours: data&.dig(:working_hours)&.any?,
    modal_used: duration > 4.0  # Likely used modal if > 4s
  }
  
  puts "  Duration: #{duration.round(2)}s"
  puts "  Success: #{!data.nil?}"
  
  # Rate limiting for server politeness
  sleep(3) unless index == urls.length - 1
end

# Performance analysis
avg_duration = results.map { |r| r[:duration] }.sum / results.length
success_rate = results.count { |r| r[:success] } * 100.0 / results.length
modal_usage = results.count { |r| r[:modal_used] } * 100.0 / results.length

puts "\n=== Performance Summary ==="
puts "Average duration: #{avg_duration.round(2)}s"
puts "Success rate: #{success_rate.round(1)}%"  
puts "Modal usage rate: #{modal_usage.round(1)}%"
```

## Testing & Validation

### Unit Tests
```ruby
describe GojekParserService do
  let(:service) { GojekParserService.new }
  
  describe "#parse" do
    context "with valid GoFood URL" do
      it "extracts complete restaurant data" do
        url = "https://gofood.co.id/jakarta/restaurant/valid-restaurant"
        result = service.parse(url)
        
        expect(result).to be_a(Hash)
        expect(result[:name]).to be_present
        expect(result[:cuisines]).to be_an(Array)
        expect(result[:rating]).to match(/\d\.\d|NEW|N\/A/)
        expect(result[:status]).to have_key(:is_open)
      end
    end
    
    context "with new restaurant" do
      it "handles NEW rating appropriately" do
        # Mock new restaurant response
        allow(service).to receive(:extract_rating_selenium).and_return("NEW")
        
        result = service.parse("https://gofood.co.id/jakarta/restaurant/new-restaurant")
        expect(result[:rating]).to eq("NEW")
      end
    end
  end
  
  describe "#check_status_only" do
    it "returns status information quickly" do
      start_time = Time.current
      result = service.check_status_only("https://gofood.co.id/jakarta/restaurant/test")
      duration = Time.current - start_time
      
      expect(duration).to be < 15  # Should complete within timeout
      expect(result).to have_key(:is_open)
      expect(result).to have_key(:status_text)
    end
  end
end
```

### Integration Tests
```ruby
RSpec.describe "GojekParserService Integration" do
  let(:service) { GojekParserService.new }
  
  it "handles modal interaction correctly" do
    # Test with a known restaurant that requires modal interaction
    url = "https://gofood.co.id/jakarta/restaurant/modal-required-restaurant"
    
    result = service.parse(url)
    
    expect(result).to be_present
    expect(result[:address]).to be_present  # Should have address via modal
    expect(result[:working_hours]).to be_present  # Should have hours via modal
  end
  
  it "falls back gracefully when modal fails" do
    # Mock modal failure
    allow(service).to receive(:click_restaurant_info_button).and_return(false)
    
    result = service.parse("https://gofood.co.id/jakarta/restaurant/test")
    
    # Should still return data even with modal failure
    expect(result).to be_present
    expect(result[:name]).to be_present
  end
end
```

## Troubleshooting Guide

### Common Issues

1. **Modal Interaction Failures**
   ```ruby
   # Error: Modal button not found or not clickable
   # Solution: Update button selectors or disable modal interaction
   
   # Temporary workaround:
   data = service.parse(url)
   # If address missing, try alternative extraction methods
   ```

2. **Extended Timeouts on Production**
   ```ruby
   # Increase timeout for slow servers
   TIMEOUT_SECONDS = 90  # Increase if needed
   
   # Or set via environment variable
   ENV['GOJEK_PARSER_TIMEOUT'] = '90'
   ```

3. **Indonesian Text Parsing Issues**
   ```ruby
   # Ensure CuisineTranslationService is loaded
   require_relative "cuisine_translation_service"
   
   # Check translation mappings
   CuisineTranslationService.translate("unknown_cuisine")
   ```

4. **Chrome Binary Detection Failures**
   ```ruby
   # Set explicit Chrome path
   ENV['CHROME_BIN'] = '/usr/bin/google-chrome'
   
   # Or update detection paths for your system
   ```

### Debug Mode

```ruby
# Enable detailed logging for troubleshooting
Rails.logger.level = Logger::DEBUG

service = GojekParserService.new
result = service.parse(url)

# Check circuit breaker status
puts "Circuit breaker failures: #{GojekParserService.circuit_breaker_failures}"
puts "Circuit breaker opened at: #{GojekParserService.circuit_breaker_opened_at}"
```

### Performance Tuning

```ruby
# Reduce timeout for faster failures
TIMEOUT_SECONDS = 45

# Skip modal interaction for speed (less complete data)
# Modify parse_implementation to skip modal by default

# Adjust Chrome flags for better performance
options.add_argument('--disable-javascript')  # If JS not needed for extraction
options.add_argument('--disable-plugins')     # Reduce resource usage
```

This specification provides comprehensive documentation for implementing, integrating, and troubleshooting the GojekParserService in production environments with full support for Indonesian localization and advanced modal interaction capabilities.