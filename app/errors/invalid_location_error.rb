class InvalidLocationError < DomainError
  def initialize(context: nil)
    super(
      message: "Invalid location.", 
      code: "invalid_location",
      http_status: 400, 
      context: context
    )
  end
end
