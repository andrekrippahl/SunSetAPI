class ApplicationController < ActionController::API
  rescue_from MissingParamsError, with: :render_domain_error
  rescue_from DomainError,        with: :render_domain_error

  rescue_from StandardError do |e|
    Rails.logger.error("[500] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    render json: { error: { code: "internal_error", message: "Unexpected error." } }, status: 500
  end

  private

  def render_domain_error(e)
    render json: ErrorSerializer.call(e), status: e.http_status
  end
end
  # UNCOMMENT IF DbConflictError
  #rescue_from ActiveRecord::RecordNotUnique do |e|
  #  render json: ErrorSerializer.call(DbConflictError.new(context: { detail: e.message })), status: 409
  #end