module ExceptionHandler
  extend ActiveSupport::Concern

  # Define custom error subclasses - rescue catches `StandardError`
  class AuthenticationError < StandardError; end

  class MissingToken < StandardError; end

  class InvalidToken < StandardError; end

  class ExpiredSignature < StandardError; end

  class DecodeError < StandardError; end

  class UnauthorizedError < StandardError; end

  included do
    # Define custom handlers
    rescue_from ActiveRecord::RecordInvalid, with: :four_twenty_two
    rescue_from ExceptionHandler::AuthenticationError, with: :unauthorized_request
    rescue_from ExceptionHandler::MissingToken, with: :four_twenty_two
    rescue_from ExceptionHandler::InvalidToken, with: :four_twenty_two
    rescue_from ExceptionHandler::ExpiredSignature, with: :four_ninety_eight
    rescue_from ExceptionHandler::DecodeError, with: :four_oh_one
    rescue_from ExceptionHandler::UnauthorizedError, with: :four_oh_three

    rescue_from ActiveRecord::RecordNotFound do |e|
      json_response({ message: e.message }, :not_found)
    end
  end

  private

  # JSON response with message; Status code 422 - unprocessable entity
  def four_twenty_two(e)
    json_response({ message: e.message }, :unprocessable_entity)
  end

  # JSON response with message; Status code 401 - Unauthorized
  def four_oh_one(e)
    json_response({ message: e.message }, :unauthorized)
  end

  # JSON response with message; Status code 401 - Unauthorized
  def unauthorized_request(e)
    json_response({ message: e.message }, :unauthorized)
  end

  # JSON response with message; Status code 498 - Invalid token
  def four_ninety_eight(e)
    json_response({ message: e.message }, :invalid_token)
  end

  # JSON response with message; Status code 403 - Forbidden
  def four_oh_three(e)
    json_response({ message: e.message }, :forbidden)
  end

  def json_response(object, status = :ok)
    render json: object, status: status
  end
end
