class AuthController < ApplicationController
  skip_before_action :authorize_request, only: [ :login, :register ]

  # POST /auth/login
  def login
    @user = User.find_by(email: user_params[:email])
    if @user&.authenticate(user_params[:password])
      token = Auth::JwtService.encode(@user.to_token_payload)
      time = Time.current + 24.hours.to_i
      render json: {
        token: token,
        exp: time.strftime("%m-%d-%Y %H:%M"),
        user: {
          id: @user.id,
          name: @user.name,
          email: @user.email
        }
      }, status: :ok
    else
      render json: { message: Message.invalid_credentials }, status: :unauthorized
    end
  end

  # POST /auth/register
  def register
    @user = User.create!(user_params)
    if @user.persisted?
      token = Auth::JwtService.encode(@user.to_token_payload)
      time = Time.current + 24.hours.to_i
      render json: {
        message: "Account created successfully! Welcome to FileNest.",
        token: token,
        exp: time.strftime("%m-%d-%Y %H:%M"),
        user: {
          id: @user.id,
          name: @user.name,
          email: @user.email
        }
      }, status: :created
    else
      render json: { message: Message.account_not_created }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      message: Message.account_not_created,
      errors: @user.errors.full_messages
    }, status: :unprocessable_entity
  end

  private

  def user_params
    params.permit(:name, :email, :password, :password_confirmation)
  end
end
