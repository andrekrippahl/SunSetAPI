class PolarDayOrNightError < DomainError
  def initialize(context: nil)
    super(
      message: "No sunrise/sunset for this date at this latitude.",
      code: "polar_day_or_night",
      http_status: 422,
      context: context
    )
  end
end
