Geocoder.configure(
  timeout: 5,
  lookup: :nominatim,          # free OpenStreetMap service
  units: :km,
  http_headers: { "User-Agent" => "sunset-app" }
)