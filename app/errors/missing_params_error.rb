class MissingParamsError < DomainError
  def initialize(context: nil)
    super(
      message: "Missing or invalid parameters.",
      code: "missing_params",
      http_status: 400,
      context: context
    )
  end
end
