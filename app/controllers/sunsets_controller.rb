# app/controllers/sunsets_controller.rb
class SunsetsController < ApplicationController
  include ActionController::Live

  def stream
    location   = params[:location]
    start_date = parse_date(params[:start])
    end_date   = parse_date(params[:end])

    if location.blank? || start_date.nil? || end_date.nil? || start_date > end_date
      response.status = 400
      return
    end

    # SSE headers
    response.headers["Content-Type"]  = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"  # evita buffering em alguns proxies

    # Resolve cidade/coords uma vez
    resolved = SunsetApiService.resolve(location)
    if resolved.nil?
      write_event("error", { error: "Location not found" })
      return
    end
    city = resolved[:city]; lat = resolved[:latitude]; lng = resolved[:longitude]

    # Buscar o que já existe numa só query
    existing = SunsetRecord.where(city: city, date: start_date..end_date).to_a
    by_date  = existing.index_by(&:date)

    begin
      (start_date..end_date).each do |date|
        record = by_date[date]

        unless record
          api = SunsetApiService.fetch_by_coords(lat, lng, date)
          if api
            # usar pool de ligações para não “segurar” a ligação durante o stream
            ActiveRecord::Base.connection_pool.with_connection do
              record = SunsetRecord.create!(
                city: city, latitude: lat, longitude: lng, date: date,
                sunrise: api[:sunrise], sunset: api[:sunset], golden_hour: api[:golden_hour]
              )
            end
          end
        end

        # envia 1 evento por linha
        write_event("record", record.as_json) if record
      end

      write_event("done", { done: true })
    rescue => e
      write_event("error", { error: e.message })
    ensure
      response.stream.close
    end
  end

  private

  # pequeno helper para emitir eventos SSE “à mão”
  def write_event(event, data)
    response.stream.write "event: #{event}\n"
    response.stream.write "data: #{data.to_json}\n\n"
  end

  def parse_date(str)
    Date.parse(str) rescue nil
  end
end
