module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :authorize_request
    attr_reader :current_user
  end

  private

  def authorize_request
    @current_user = AuthorizeApiRequest.new(request.headers).call[:user]
  rescue ExceptionHandler::MissingToken, ExceptionHandler::InvalidToken, ExceptionHandler::ExpiredSignature, ExceptionHandler::DecodeError => e
    render json: { message: e.message }, status: :unauthorized
  rescue ExceptionHandler::AuthenticationError => e
    render json: { message: e.message }, status: :unauthorized
  end

  def current_user
    @current_user
  end

  def require_authentication!
    raise ExceptionHandler::AuthenticationError, "Authentication required" unless current_user
  end

  def authorize_file_access!(user_file)
    unless user_file.user_id == current_user.id
      raise ExceptionHandler::UnauthorizedError, "You can only access your own files"
    end
  end
end
