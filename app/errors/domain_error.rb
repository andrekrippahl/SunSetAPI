class DomainError < StandardError
  attr_reader :code, :http_status, :context

  def initialize(message: nil, code:, http_status:, context: nil)
    @code = code
    @http_status = http_status
    @context = context
    super(message)
  end
end
