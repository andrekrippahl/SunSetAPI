require "rails_helper"

RSpec.describe "Sunsets", type: :request do
  let(:city) { "Lisbon" }
  let(:lat)  { "38.7169" }
  let(:lng)  { "-9.1390" }

  def json
    JSON.parse(response.body)
  end

  describe "GET /sunsets (classic)" do
    it "returns 400 missing_params when required params are absent" do
      get "/sunsets", params: { location: "", start: "", end: "" }

      expect(response.status).to eq(400)
      expect(json["error"]["code"]).to eq("missing_params")
    end

    it "returns 422 geocoding_failed when location cannot be resolved" do
      allow(SunsetApiService).to receive(:resolve)
        .and_raise(GeocodingFailedError.new(context: { location: "???" }))

      get "/sunsets", params: { location: "???", start: "2025-01-01", end: "2025-01-01" }

      expect(response.status).to eq(422)
      expect(json["error"]["code"]).to eq("geocoding_failed")
    end

    it "creates and returns records when none exist (happy path)" do
      allow(SunsetApiService).to receive(:resolve)
        .and_return({ city: city, latitude: lat, longitude: lng })

      # Stub upstream fetch for each date
      allow(SunsetApiService).to receive(:fetch_by_coords)
        .with(lat, lng, Date.parse("2025-01-01"))
        .and_return({ sunrise: "2025-01-01T07:51:00Z", sunset: "2025-01-01T17:23:00Z", golden_hour: "gh" })

      expect {
        get "/sunsets", params: { location: city, start: "2025-01-01", end: "2025-01-01" }
      }.to change { SunsetRecord.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(json).to be_an(Array)
      expect(json.first).to include(
        "city" => city,
        "sunrise" => "2025-01-01T07:51:00Z",
        "sunset"  => "2025-01-01T17:23:00Z"
      )
    end

    it "uses cached DB records and does not call upstream again" do
      SunsetRecord.create!(
        city: city, latitude: lat, longitude: lng,
        date: Date.parse("2025-01-01"),
        sunrise: "S", sunset: "E", golden_hour: "gh"
      )

      allow(SunsetApiService).to receive(:resolve)
        .and_return({ city: city, latitude: lat, longitude: lng })

      # Ensure we DON'T hit the API for an already-cached date
      expect(SunsetApiService).not_to receive(:fetch_by_coords)

      get "/sunsets", params: { location: city, start: "2025-01-01", end: "2025-01-01" }

      expect(response).to have_http_status(:ok)
      expect(json.size).to eq(1)
      expect(json.first).to include("sunrise" => "S", "sunset" => "E")
    end

    it "maps upstream timeouts to 504" do
      allow(SunsetApiService).to receive(:resolve)
        .and_return({ city: city, latitude: lat, longitude: lng })

      allow(SunsetApiService).to receive(:fetch_by_coords)
        .and_raise(UpstreamTimeoutError.new)

      get "/sunsets", params: { location: city, start: "2025-01-01", end: "2025-01-01" }

      expect(response.status).to eq(504)
      expect(json["error"]["code"]).to eq("upstream_timeout")
    end
  end
end
