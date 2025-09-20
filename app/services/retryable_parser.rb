require "selenium-webdriver"

class RetryableParser
  RETRY_DELAYS = [2, 4, 8].freeze # Exponential backoff in seconds
  MAX_RETRIES = 3
  CIRCUIT_BREAKER_THRESHOLD = 5
  CIRCUIT_BREAKER_RESET_TIME = 30 # seconds

  class << self
    attr_accessor :circuit_breaker_failures, :circuit_breaker_opened_at
  end

  self.circuit_breaker_failures = 0
  self.circuit_breaker_opened_at = nil

  # Recoverable errors that should trigger retry
  RECOVERABLE_ERRORS = [
    Selenium::WebDriver::Error::InvalidSessionIdError,
    Selenium::WebDriver::Error::WebDriverError,
    Selenium::WebDriver::Error::UnknownError,
    Selenium::WebDriver::Error::SessionNotCreatedError,
    Timeout::Error,
    Net::ReadTimeout,
    Net::OpenTimeout,
    Errno::ECONNREFUSED,
    Errno::ECONNRESET
  ].freeze

  # Non-recoverable errors that should not trigger retry
  NON_RECOVERABLE_ERRORS = [
    Selenium::WebDriver::Error::NoSuchElementError,
    Selenium::WebDriver::Error::InvalidArgumentError,
    ArgumentError,
    URI::InvalidURIError
  ].freeze

  def parse_with_retry(url)
    return nil if url.blank?

    # Check circuit breaker
    if circuit_breaker_open?
      Rails.logger.warn "Circuit breaker is OPEN, skipping parse attempt"
      return nil
    end

    attempt = 0
    last_error = nil

    while attempt < MAX_RETRIES
      attempt += 1
      start_time = Time.current

      begin
        Rails.logger.info "=== Attempt #{attempt}/#{MAX_RETRIES} for #{parser_name} ===" 
        Rails.logger.info "URL: #{url}"

        result = parse_implementation(url)
        
        if result
          duration = Time.current - start_time
          Rails.logger.info "✅ #{parser_name} SUCCESS on attempt #{attempt} (#{duration.round(2)}s)"
          
          # Reset circuit breaker on success
          reset_circuit_breaker
          return result
        else
          Rails.logger.warn "⚠️ #{parser_name} returned nil on attempt #{attempt}"
          last_error = StandardError.new("Parser returned nil")
        end

      rescue *RECOVERABLE_ERRORS => e
        duration = Time.current - start_time
        last_error = e
        
        Rails.logger.warn "🔄 #{parser_name} RECOVERABLE ERROR on attempt #{attempt} (#{duration.round(2)}s)"
        Rails.logger.warn "   Error: #{e.class} - #{e.message}"
        
        # Cleanup driver before retry
        cleanup_driver_resources
        
        # Wait before retry (except on last attempt)
        if attempt < MAX_RETRIES
          delay = RETRY_DELAYS[attempt - 1] || RETRY_DELAYS.last
          Rails.logger.info "   ⏳ Waiting #{delay}s before retry..."
          sleep(delay)
        end

      rescue *NON_RECOVERABLE_ERRORS => e
        duration = Time.current - start_time
        Rails.logger.error "❌ #{parser_name} NON-RECOVERABLE ERROR on attempt #{attempt} (#{duration.round(2)}s)"
        Rails.logger.error "   Error: #{e.class} - #{e.message}"
        
        # Don't retry non-recoverable errors
        break

      rescue => e
        duration = Time.current - start_time
        last_error = e
        
        Rails.logger.error "💥 #{parser_name} UNEXPECTED ERROR on attempt #{attempt} (#{duration.round(2)}s)"
        Rails.logger.error "   Error: #{e.class} - #{e.message}"
        Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join("\n")}"
        
        # Treat unknown errors as potentially recoverable
        cleanup_driver_resources
        
        if attempt < MAX_RETRIES
          delay = RETRY_DELAYS[attempt - 1] || RETRY_DELAYS.last
          Rails.logger.info "   ⏳ Waiting #{delay}s before retry..."
          sleep(delay)
        end
      end
    end

    # All attempts failed
    Rails.logger.error "❌ #{parser_name} FAILED after #{MAX_RETRIES} attempts"
    Rails.logger.error "   Last error: #{last_error&.class} - #{last_error&.message}"
    
    # Update circuit breaker
    increment_circuit_breaker_failures
    
    nil
  end

  private

  def parser_name
    self.class.name.gsub('Service', '').gsub('Parser', '')
  end

  def circuit_breaker_open?
    return false unless self.class.circuit_breaker_opened_at
    
    Time.current - self.class.circuit_breaker_opened_at < CIRCUIT_BREAKER_RESET_TIME
  end

  def reset_circuit_breaker
    if self.class.circuit_breaker_failures && self.class.circuit_breaker_failures > 0
      Rails.logger.info "🔧 Circuit breaker RESET (was #{self.class.circuit_breaker_failures} failures)"
    end
    
    self.class.circuit_breaker_failures = 0
    self.class.circuit_breaker_opened_at = nil
  end

  def increment_circuit_breaker_failures
    self.class.circuit_breaker_failures = (self.class.circuit_breaker_failures || 0) + 1
    
    if self.class.circuit_breaker_failures >= CIRCUIT_BREAKER_THRESHOLD
      self.class.circuit_breaker_opened_at = Time.current
      
      Rails.logger.error "🚨 Circuit breaker OPENED after #{self.class.circuit_breaker_failures} failures"
      Rails.logger.error "   Will remain open for #{CIRCUIT_BREAKER_RESET_TIME}s"
    else
      Rails.logger.warn "⚠️ Circuit breaker failure count: #{self.class.circuit_breaker_failures}/#{CIRCUIT_BREAKER_THRESHOLD}"
    end
  end

  def cleanup_driver_resources
    # Subclasses should implement specific cleanup logic
    Rails.logger.debug "🧹 Cleaning up driver resources..."
  end

  # Subclasses must implement this method
  def parse_implementation(url)
    raise NotImplementedError, "Subclasses must implement parse_implementation"
  end
end