class SunsetsController < ApplicationController
  def index
    location   = params[:location]            # "Lisbon" OR "38.7169,-9.1390"
    start_date = parse_date(params[:start])
    end_date   = parse_date(params[:end])

    if location.blank? || start_date.nil? || end_date.nil? || start_date > end_date
      return render json: { error: "Invalid parameters" }, status: :bad_request
    end

    # 1) Resolve location once (city, lat, lng)
    resolved = SunsetApiService.resolve(location)  # you'll add this method (see below)
    return render json: { error: "Location not found" }, status: :bad_request if resolved.nil?

    city = resolved[:city]
    lat  = resolved[:latitude]
    lng  = resolved[:longitude]

    # 2) Fetch existing records for the whole range in one query (faster than find_by in a loop)
    existing = SunsetRecord.where(city: city, date: start_date..end_date).to_a
    by_date  = existing.index_by(&:date)

    results = []
    (start_date..end_date).each do |date|
      record = by_date[date]

      unless record
        api_data = SunsetApiService.fetch_by_coords(lat, lng, date)  # pass lat/lng to API
        if api_data
          record = SunsetRecord.create!(
            city:        city,
            latitude:    lat,
            longitude:   lng,
            date:        date,
            sunrise:     api_data[:sunrise],
            sunset:      api_data[:sunset],
            golden_hour: api_data[:golden_hour]
          )
        end
      end

      results << record if record
    end

    render json: results
  end

  private

  def parse_date(str)
    Date.parse(str) rescue nil
  end
end
