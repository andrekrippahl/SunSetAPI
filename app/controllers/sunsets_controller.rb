class SunsetsController < ApplicationController
  include ActionController::Live  # needed only for #stream

  # Classic endpoint: collect then return JSON
  def index
    location   = params[:location]
    start_date = parse_date(params[:start])
    end_date   = parse_date(params[:end])

    # raise a domain error on bad params
    raise MissingParamsError.new(context: params.slice(:location, :start, :end)) \
      if location.blank? || start_date.nil? || end_date.nil? || start_date > end_date

    resolved = SunsetApiService.resolve(location)  # raises InvalidLocation/GeocodingFailed
    city, lat, lng = resolved.values_at(:city, :latitude, :longitude)

    existing = SunsetRecord.where(city: city, date: start_date..end_date).to_a
    by_date  = existing.index_by(&:date)

    results = []
    (start_date..end_date).each do |date|
      record = by_date[date]
      unless record
        api = SunsetApiService.fetch_by_coords(lat, lng, date) 
        record = SunsetRecord.create!(
          city: city, latitude: lat, longitude: lng, date: date,
          sunrise: api[:sunrise], sunset: api[:sunset], golden_hour: api[:golden_hour]
        )
      end
      results << record
    end

    render json: results

  rescue DomainError => e
      # render your structured error (same shape as SSE)
      render json: ErrorSerializer.call(e), status: e.http_status
  rescue => e
      Rails.logger.error("[/sunsets 500] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
      render json: { error: { code: "internal_error", message: "Unexpected error." } }, status: 500
  end


  # Streaming (SSE): send one event per record
  def stream
    location   = params[:location]
    start_date = parse_date(params[:start])
    end_date   = parse_date(params[:end])

    response.headers["Content-Type"]      = "text/event-stream"
    response.headers["Cache-Control"]     = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    # Validate early; serialize error event and close
    if location.blank? || start_date.nil? || end_date.nil? || start_date > end_date
      write_event("error", ErrorSerializer.call(MissingParamsError.new(context: params.slice(:location, :start, :end)))[:error])
      return
    end

    # Resolve once (emit error and close if it fails)
    resolved = SunsetApiService.resolve(location)
    city, lat, lng = resolved.values_at(:city, :latitude, :longitude)

    existing = SunsetRecord.where(city: city, date: start_date..end_date).to_a
    by_date  = existing.index_by(&:date)

    (start_date..end_date).each do |date|
      record = by_date[date]

      unless record
        api = SunsetApiService.fetch_by_coords(lat, lng, date)
        ActiveRecord::Base.connection_pool.with_connection do
          record = SunsetRecord.create!(
            city: city, latitude: lat, longitude: lng, date: date,
            sunrise: api[:sunrise], sunset: api[:sunset], golden_hour: api[:golden_hour]
          )
        end
      end

      write_event("record", record.as_json)
    end

    write_event("done", { done: true })
  rescue DomainError => e
    # Step 7: emit domain error in the stream and close
    write_event("error", ErrorSerializer.call(e)[:error])
  rescue => e
    Rails.logger.error("[SSE] #{e.class}: #{e.message}")
    write_event("error", { code: "internal_error", message: "Unexpected error." })
  ensure
    response.stream.close
  end

  private

  def parse_date(str)
    Date.parse(str) rescue nil
  end

  def write_event(event, data)
    response.stream.write "event: #{event}\n"
    response.stream.write "data: #{data.to_json}\n\n"
  end
end
