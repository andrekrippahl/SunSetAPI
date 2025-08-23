class GeocodingFailedError < DomainError
  def initialize(context: nil)
    super(message: "Could not resolve location.", code: "geocoding_failed", http_status: 422, context: context)
  end
end
