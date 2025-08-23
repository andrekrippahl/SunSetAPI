require "net/http"
require "json"
require "uri"

class SunsetApiService
  BASE_URL = "https://api.sunrise-sunset.org/json"

  # Accepts "Lisbon" or "lat,lng".
  # Raises: InvalidLocationError, GeocodingFailedError
# app/services/sunset_api_service.rb
  def self.resolve(location)
    if location.to_s.include?(",")
      lat, lng = location.split(",", 2).map(&:strip)
      raise InvalidLocationError.new(context: { location: location }) if lat.blank? || lng.blank?
      { city: "Unknown", latitude: lat, longitude: lng }
    else
      geo = Geocoder.search(location).first
      raise GeocodingFailedError.new(context: { location: location }) unless geo
      { city: (geo.city || location), latitude: geo.coordinates[0], longitude: geo.coordinates[1] }
    end
  end


  # Calls upstream API with coordinates.
  # Raises: UpstreamTimeoutError, UpstreamRateLimitedError, UpstreamBadResponseError, PolarDayOrNightError
  def self.fetch_by_coords(lat, lng, date)
    uri = URI("#{BASE_URL}?lat=#{lat}&lng=#{lng}&date=#{date}&formatted=0")
  
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 8

    res = http.get(uri.request_uri)

    case res.code.to_i
    when 200
      body = JSON.parse(res.body)
      data = body["results"]
      # Some locations/dates return no sunrise/sunset (polar day/night)
      if data.nil? || data["sunrise"].nil? || data["sunset"].nil? || data["sunrise"] == "-" || data["sunset"] == "-"
        raise PolarDayOrNightError.new(context: { latitude: lat, longitude: lng, date: date })
      end
      {
        sunrise: data["sunrise"],
        sunset:  data["sunset"],
        golden_hour: "#{data["sunrise"]} - #{data["sunset"]}"
      }
    when 429
      raise UpstreamRateLimitedError.new(context: { provider: "sunrise-sunset", status: 429 })
    else
      raise UpstreamBadResponseError.new(context: { provider: "sunrise-sunset", status: res.code, body: safe_body(res.body) })
    end
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise UpstreamTimeoutError.new(context: { provider: "sunrise-sunset" })
  rescue JSON::ParserError
    raise UpstreamBadResponseError.new(context: { provider: "sunrise-sunset", reason: "invalid_json" })
  end

  def self.safe_body(b)
    b.to_s[0, 500] # avoid huge logs
  end
end
