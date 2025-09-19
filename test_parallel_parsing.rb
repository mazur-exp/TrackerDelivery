#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'thread'

# Test parallel parsing performance
def test_parallel_vs_sequential
  puts "=" * 80
  puts "TESTING PARALLEL vs SEQUENTIAL PARSING"
  puts "=" * 80
  
  # Test URLs
  gojek_url = "https://gofood.link/a/qpKr7VkG"
  grab_url = "https://r.grab.com/g/6-20250919_181803_8015D1829687499383E150126C5CEFCA_MEXMPS-6-C7BJC6A3CRMZNT"
  
  # CSRF token (you'll need to get this from the browser)
  csrf_token = "placeholder_token"
  
  base_url = "http://localhost:3000"
  
  # Test 1: Sequential parsing (old way)
  puts "\n🔄 Testing SEQUENTIAL parsing..."
  sequential_start = Time.now
  
  begin
    response = make_request("#{base_url}/restaurants/extract_data", {
      grab_url: grab_url,
      gojek_url: gojek_url
    }, csrf_token)
    
    sequential_time = Time.now - sequential_start
    puts "✅ Sequential completed in #{sequential_time.round(2)}s"
    
    if response['success']
      puts "   Platforms: #{response['platforms']&.join(', ')}"
    else
      puts "   Error: #{response['errors']&.join(', ')}"
    end
  rescue => e
    puts "❌ Sequential failed: #{e.message}"
  end
  
  # Test 2: Parallel parsing (new way)
  puts "\n⚡ Testing PARALLEL parsing..."
  parallel_start = Time.now
  
  threads = []
  results = {}
  
  # Start GoJek request
  if gojek_url
    threads << Thread.new do
      begin
        result = make_request("#{base_url}/restaurants/extract_gojek_data", {
          gojek_url: gojek_url
        }, csrf_token)
        results[:gojek] = { result: result, time: Time.now - parallel_start }
      rescue => e
        results[:gojek] = { error: e.message, time: Time.now - parallel_start }
      end
    end
  end
  
  # Start Grab request
  if grab_url
    threads << Thread.new do
      begin
        result = make_request("#{base_url}/restaurants/extract_grab_data", {
          grab_url: grab_url
        }, csrf_token)
        results[:grab] = { result: result, time: Time.now - parallel_start }
      rescue => e
        results[:grab] = { error: e.message, time: Time.now - parallel_start }
      end
    end
  end
  
  # Wait for all threads to complete
  threads.each(&:join)
  parallel_time = Time.now - parallel_start
  
  puts "✅ Parallel completed in #{parallel_time.round(2)}s"
  
  # Show individual results
  results.each do |platform, data|
    if data[:result]
      status = data[:result]['success'] ? '✅' : '❌'
      puts "   #{platform.capitalize}: #{status} (#{data[:time].round(2)}s)"
    else
      puts "   #{platform.capitalize}: ❌ #{data[:error]} (#{data[:time].round(2)}s)"
    end
  end
  
  # Calculate improvement
  if sequential_time > 0 && parallel_time > 0
    improvement = ((sequential_time - parallel_time) / sequential_time * 100).round(1)
    puts "\n📊 PERFORMANCE IMPROVEMENT:"
    puts "   Sequential: #{sequential_time.round(2)}s"
    puts "   Parallel:   #{parallel_time.round(2)}s"
    puts "   Speedup:    #{improvement}% faster"
    
    # Time to first result (should be much faster with parallel)
    first_result_time = results.values.map { |d| d[:time] }.min
    if first_result_time
      first_improvement = ((sequential_time - first_result_time) / sequential_time * 100).round(1)
      puts "   First result: #{first_result_time.round(2)}s (#{first_improvement}% faster)"
    end
  end
end

def make_request(url, data, csrf_token)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request['X-CSRF-Token'] = csrf_token
  request.body = data.to_json
  
  response = http.request(request)
  JSON.parse(response.body)
end

# Run the test
if __FILE__ == $0
  puts "⚠️  NOTE: This test requires a running Rails server on localhost:3000"
  puts "⚠️  You may need to update the CSRF token for this to work properly"
  puts
  
  test_parallel_vs_sequential
end