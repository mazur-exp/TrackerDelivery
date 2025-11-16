class ParserTestController < ApplicationController
  # Skip authentication and CSRF for testing endpoints
  skip_before_action :require_authentication
  skip_before_action :verify_authenticity_token, only: [:test_grab, :test_gojek]

  def index
    # Main testing page with forms for both parsers
  end

  def test_grab
    url = params[:url]

    if url.blank?
      render json: { success: false, error: "URL parameter is required" }, status: 400
      return
    end

    begin
      start_time = Time.current

      # Use Grab API Parser (JWT-based, official API v2)
      parser = GrabApiParserService.new
      data = parser.parse(url)

      duration = Time.current - start_time

      if data && data[:name]
        render json: {
          success: true,
          parser: "GrabApiParserService (JWT + API v2)",
          data: data,
          duration: duration.round(2),
          quality: calculate_quality(data),
          timestamp: Time.current.iso8601
        }
      else
        render json: {
          success: false,
          error: "Failed to parse restaurant data",
          duration: duration.round(2)
        }, status: 422
      end

    rescue => e
      Rails.logger.error "Grab parser test error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      render json: {
        success: false,
        error: "#{e.class}: #{e.message}",
        backtrace: e.backtrace.first(3)
      }, status: 500
    end
  end

  def test_gojek
    url = params[:url]

    if url.blank?
      render json: { success: false, error: "URL parameter is required" }, status: 400
      return
    end

    begin
      start_time = Time.current

      # Use HTTP GoJek Parser (fast, __NEXT_DATA__ based)
      parser = HttpGojekParserService.new
      data = parser.parse(url)

      duration = Time.current - start_time

      if data && data[:name]
        render json: {
          success: true,
          parser: "HttpGojekParserService (__NEXT_DATA__)",
          data: data,
          duration: duration.round(2),
          quality: calculate_quality(data),
          timestamp: Time.current.iso8601
        }
      else
        render json: {
          success: false,
          error: "Failed to parse restaurant data",
          duration: duration.round(2)
        }, status: 422
      end

    rescue => e
      Rails.logger.error "GoJek parser test error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")

      render json: {
        success: false,
        error: "#{e.class}: #{e.message}",
        backtrace: e.backtrace.first(3)
      }, status: 500
    end
  end

  private

  def calculate_quality(data)
    return 0 if data.nil? || data.empty?

    score = 0
    score += 30 if data[:name].present?
    score += 20 if data[:address].present?
    score += 15 if data[:rating].present?
    score += 10 if data[:cuisines]&.any?
    score += 10 if data[:image_url].present?
    score += 10 if data[:status].present?
    score += 5 if (data[:opening_hours]&.any? || data[:open_periods]&.any?)

    score
  end
end
