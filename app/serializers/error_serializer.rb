class ErrorSerializer
  def self.call(error)
    {
      error: {
        code: error.respond_to?(:code) ? error.code : "internal_error",
        message: error.message,
        hint: hint_for(error),
        context: (error.respond_to?(:context) ? error.context : nil)
      }.compact
    }
  end

  def self.hint_for(error)
    case error&.code
    when "invalid_location", "geocoding_failed"
      "Try a city name like 'Lisbon.'"
    when "missing_params"
      "Required query params: location, start, end."
    else
      nil
    end
  end
end
