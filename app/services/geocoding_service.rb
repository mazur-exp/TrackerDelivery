require 'net/http'
require 'uri'
require 'json'

class GeocodingService
  TIMEOUT_SECONDS = 10
  
  def self.reverse_geocode(latitude, longitude)
    new.reverse_geocode(latitude, longitude)
  end
  
  def reverse_geocode(latitude, longitude)
    Rails.logger.info "=== Geocoding coordinates: #{latitude}, #{longitude} ==="
    
    begin
      address = try_nominatim(latitude, longitude)
      
      if address
        Rails.logger.info "Geocoding success: #{address}"
        return {
          success: true,
          address: address,
          source: 'OpenStreetMap Nominatim'
        }
      else
        Rails.logger.warn "Geocoding failed: no address found"
        return {
          success: false,
          address: nil,
          source: nil,
          error: 'No address found for coordinates'
        }
      end
      
    rescue => e
      Rails.logger.error "Geocoding error: #{e.class} - #{e.message}"
      return {
        success: false,
        address: nil,
        source: nil,
        error: e.message
      }
    end
  end
  
  private
  
  def try_nominatim(latitude, longitude)
    url = "https://nominatim.openstreetmap.org/reverse"
    params = {
      'format' => 'json',
      'lat' => latitude.to_s,
      'lon' => longitude.to_s,
      'zoom' => '18',
      'addressdetails' => '1'
    }
    
    query_string = params.map { |k, v| "#{k}=#{CGI.escape(v)}" }.join('&')
    uri = URI("#{url}?#{query_string}")
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = TIMEOUT_SECONDS
    http.open_timeout = TIMEOUT_SECONDS
    
    request = Net::HTTP::Get.new(uri)
    request['User-Agent'] = 'TrackerDelivery/1.0 (restaurant-tracker)'
    request['Accept'] = 'application/json'
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      
      # First try display_name
      return data['display_name'] if data['display_name']
      
      # Fallback: build address from components
      if data['address']
        addr = data['address']
        parts = []
        
        # Build Indonesian-style address
        parts << addr['house_number'] if addr['house_number']
        parts << addr['road'] if addr['road']
        parts << addr['suburb'] if addr['suburb']
        parts << addr['village'] if addr['village']
        parts << addr['city'] if addr['city']
        parts << addr['state'] if addr['state']
        
        return parts.join(', ') if parts.any?
      end
    else
      Rails.logger.warn "Nominatim HTTP error: #{response.code} #{response.message}"
    end
    
    nil
  end
end