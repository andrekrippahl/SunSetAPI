class UpstreamTimeoutError < DomainError
  def initialize(context: nil)
    super(
      message: "Upstream service timed out.",
      code: "upstream_timeout",
      http_status: 504,
      context: context
    )
  end
end
