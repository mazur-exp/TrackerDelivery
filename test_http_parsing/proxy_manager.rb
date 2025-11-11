#!/usr/bin/env ruby

class ProxyManager
  attr_reader :proxies, :current_index, :request_count

  MAX_REQUESTS_PER_PROXY = 30

  def initialize(proxy_file = nil)
    @proxies = []
    @current_index = 0
    @request_count = 0
    @max_requests_per_proxy = MAX_REQUESTS_PER_PROXY

    load_from_file(proxy_file) if proxy_file && File.exist?(proxy_file)
  end

  def load_from_file(filepath)
    File.readlines(filepath).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?('#')

      # Format: ip:port:username:password
      parts = line.split(':')
      if parts.length == 4
        ip, port, user, password = parts
        proxy_url = "http://#{user}:#{password}@#{ip}:#{port}"
        @proxies << proxy_url
      elsif parts.length == 2
        # Format: ip:port (no auth)
        ip, port = parts
        proxy_url = "http://#{ip}:#{port}"
        @proxies << proxy_url
      end
    end

    puts "Loaded #{@proxies.length} proxies from #{filepath}"
  end

  def get_current_proxy
    return nil if @proxies.empty?
    @proxies[@current_index]
  end

  def increment_requests
    @request_count += 1
    if should_rotate?
      rotate
    end
  end

  def should_rotate?
    @request_count >= @max_requests_per_proxy
  end

  def rotate
    return if @proxies.empty?

    @current_index = (@current_index + 1) % @proxies.length
    @request_count = 0

    puts "🔄 Rotated to proxy #{@current_index + 1}/#{@proxies.length}"
  end

  def force_rotate
    rotate
  end

  def to_httparty_format
    proxy = get_current_proxy
    return nil unless proxy

    # Parse proxy URL for HTTParty format
    uri = URI.parse(proxy)

    {
      http_proxyaddr: uri.host,
      http_proxyport: uri.port,
      http_proxyuser: uri.user,
      http_proxypass: uri.password
    }
  end

  def stats
    {
      total: @proxies.length,
      current: @current_index + 1,
      requests: @request_count,
      next_rotation_at: @max_requests_per_proxy - @request_count
    }
  end
end
