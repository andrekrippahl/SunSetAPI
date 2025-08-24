require "net/http"
require "json"
require "uri"

class SunsetApiService
  BASE_URL = "https://api.sunrise-sunset.org/json" 

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


def self.fetch_by_coords(lat, lng, date)
  uri  = URI("#{BASE_URL}?lat=#{lat}&lng=#{lng}&date=#{date}&formatted=0")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = true
  http.open_timeout = 5
  http.read_timeout = 8

  res = http.get(uri.request_uri)

  case res.code.to_i
  when 200
    body = JSON.parse(res.body)

 
    raw  = body["results"]
    data = raw.is_a?(Array) ? raw.first : raw
    raise UpstreamBadResponseError.new(context: { reason: "missing_results", body: safe_body(res.body) }) unless data.is_a?(Hash)

    sunrise    = data["sunrise"]
    sunset     = data["sunset"]
    day_length = data["day_length"]


    if polar_like?(sunrise, sunset, day_length)
      raise PolarDayOrNightError.new(context: { latitude: lat, longitude: lng, date: date })
    end

    {
      sunrise: sunrise,
      sunset:  sunset,
      golden_hour: data["golden_hour"] || "#{sunrise} - #{sunset}"
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


  def self.polar_like?(sunrise, sunset, day_length)
    return true if sunrise.nil? || sunset.nil?
    return true if sunrise == "-" || sunset == "-"
    return true if sunrise.to_s.start_with?("1970-01-01") || sunset.to_s.start_with?("1970-01-01")
    return true if day_length.to_s.include?("NaN") || day_length.to_s == "00:00:00"
    false
  end

  def self.safe_body(b)
    b.to_s[0, 500]
  end
end
