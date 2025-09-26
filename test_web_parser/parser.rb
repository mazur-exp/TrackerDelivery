#!/usr/bin/env ruby

require 'webrick'
require 'json'
require 'cgi'
require_relative '../test_http_parsing/test_grab_http'
require_relative '../test_http_parsing/test_gojek_http'

class ParserServer
  def initialize(port = 3000)
    @port = port
    @grab_parser = TestGrabHttpParser.new
    @gojek_parser = TestGojekHttpParser.new
  end
  
  def start
    # Set document root to test_web_parser directory
    doc_root = File.dirname(__FILE__)
    server = WEBrick::HTTPServer.new(
      Port: @port, 
      DocumentRoot: doc_root,
      Logger: WEBrick::Log.new(STDERR, WEBrick::Log::INFO)
    )
    
    # Serve static files
    server.mount('/', WEBrick::HTTPServlet::FileHandler, doc_root)
    
    # API endpoint for parsing
    server.mount_proc('/parse') do |req, res|
      handle_parse_request(req, res)
    end
    
    # Redirect /test to main page
    server.mount_proc('/test') do |req, res|
      if req.request_method == 'GET'
        res.status = 302
        res['Location'] = '/index.html'
      else
        handle_parse_request(req, res)
      end
    end
    
    puts "🚀 HTTP Parser Test Server запущен!"
    puts "📍 Откройте: http://localhost:#{@port}/test"
    puts "⏹️  Для остановки нажмите Ctrl+C"
    puts "-" * 50
    
    trap('INT') { server.shutdown }
    server.start
  end
  
  private
  
  def handle_parse_request(req, res)
    # Set CORS headers
    res['Access-Control-Allow-Origin'] = '*'
    res['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    res['Access-Control-Allow-Headers'] = 'Content-Type'
    res['Content-Type'] = 'application/json'
    
    if req.request_method == 'OPTIONS'
      res.status = 200
      return
    end
    
    unless req.request_method == 'POST'
      res.status = 405
      res.body = JSON.generate({ error: 'Method not allowed' })
      return
    end
    
    begin
      # Parse form data
      if req.content_type&.include?('multipart/form-data')
        form_data = {}
        req.body.split(req.content_type.match(/boundary=(.+)/)[1]).each do |part|
          if part.include?('Content-Disposition')
            name_match = part.match(/name="([^"]+)"/)
            if name_match
              name = name_match[1]
              value = part.split("\r\n\r\n")[1]&.strip&.chomp("\r\n--")
              form_data[name] = value if value && !value.empty?
            end
          end
        end
      else
        # Handle URL-encoded data
        form_data = CGI.parse(req.body || '')
        form_data = form_data.transform_values { |v| v.first }
      end
      
      grab_url = form_data['grab_url']
      gojek_url = form_data['gojek_url']
      
      results = {}
      
      # Parse Grab URL if provided
      if grab_url && !grab_url.empty?
        puts "Парсинг Grab URL: #{grab_url}"
        grab_result = parse_with_timing('grab', grab_url) { @grab_parser.test_parse(grab_url) }
        results[:grab] = grab_result
      end
      
      # Parse GoJek URL if provided
      if gojek_url && !gojek_url.empty?
        puts "Парсинг GoJek URL: #{gojek_url}"
        gojek_result = parse_with_timing('gojek', gojek_url) { @gojek_parser.test_parse(gojek_url) }
        results[:gojek] = gojek_result
      end
      
      res.status = 200
      res.body = JSON.generate(results)
      
    rescue => e
      puts "Ошибка парсинга: #{e.message}"
      puts e.backtrace.first(5)
      
      res.status = 500
      res.body = JSON.generate({
        error: e.message,
        type: e.class.name
      })
    end
  end
  
  def parse_with_timing(platform, url)
    start_time = Time.now
    
    begin
      result = yield
      duration = Time.now - start_time
      
      if result[:success]
        quality = calculate_quality(result[:data])
        
        {
          success: true,
          data: result[:data],
          duration: duration,
          quality: quality,
          platform: platform,
          url: url
        }
      else
        {
          success: false,
          error: result[:error],
          duration: duration,
          quality: 0,
          platform: platform,
          url: url
        }
      end
      
    rescue => e
      duration = Time.now - start_time
      
      {
        success: false,
        error: "#{e.class.name}: #{e.message}",
        duration: duration,
        quality: 0,
        platform: platform,
        url: url
      }
    end
  end
  
  def calculate_quality(data)
    return 0 if data.nil? || data.empty?
    
    score = 0
    
    # Name is most important (30 points)
    score += 30 if data[:name] && !data[:name].empty?
    
    # Address is very important (25 points)  
    score += 25 if data[:address] && !data[:address].empty?
    
    # Rating is important (20 points)
    score += 20 if data[:rating] && !data[:rating].empty?
    
    # Cuisines are important (15 points)
    score += 15 if data[:cuisines]&.any?
    
    # Coordinates are valuable (5 points)
    score += 5 if data[:coordinates] && !data[:coordinates].empty?
    
    # Image is nice to have (5 points)
    score += 5 if data[:image_url] && !data[:image_url].empty?
    
    score
  end
end

# Start server if called directly
if __FILE__ == $0
  port = ARGV[0]&.to_i || 3000
  server = ParserServer.new(port)
  server.start
end