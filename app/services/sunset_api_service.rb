# app/services/sunset_api_service.rb
class SunsetApiService
  BASE_URL = "https://api.sunrise-sunset.org/json"

  # Resolve once before the loop
  def self.resolve(location)
    if location.include?(",")
      lat, lng = location.split(",", 2).map(&:strip)
      { city: "Unknown", latitude: lat, longitude: lng }
    else
      geo = Geocoder.search(location).first
      return nil unless geo
      { city: (geo.city || location), latitude: geo.coordinates[0], longitude: geo.coordinates[1] }
    end
  end

  # Call API with coordinates
  def self.fetch_by_coords(lat, lng, date)
    uri = URI("#{BASE_URL}?lat=#{lat}&lng=#{lng}&date=#{date}&formatted=0")
    res = Net::HTTP.get_response(uri)
    return nil unless res.is_a?(Net::HTTPSuccess)
    data = JSON.parse(res.body)["results"]
    {
      sunrise: data["sunrise"],
      sunset:  data["sunset"],
      golden_hour: "#{data["sunrise"]} - #{data["sunset"]}"
    }
  rescue => e
    Rails.logger.error("SunsetApiService error: #{e.message}")
    nil
  end
end
