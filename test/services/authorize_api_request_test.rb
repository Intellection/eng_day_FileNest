require "test_helper"

class AuthorizeApiRequestTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @valid_token = Auth::JwtService.encode(@user.to_token_payload)
    @headers_with_valid_token = { "Authorization" => "Bearer #{@valid_token}" }
  end

  test "should return user for valid authorization header" do
    service = AuthorizeApiRequest.new(@headers_with_valid_token)
    result = service.call

    assert_equal @user, result[:user]
  end

  test "should raise MissingToken when no Authorization header" do
    service = AuthorizeApiRequest.new({})

    assert_raises ExceptionHandler::MissingToken do
      service.call
    end
  end

  test "should raise MissingToken when Authorization header is empty" do
    headers = { "Authorization" => "" }
    service = AuthorizeApiRequest.new(headers)

    assert_raises ExceptionHandler::MissingToken do
      service.call
    end
  end

  test "should raise MissingToken when Authorization header is nil" do
    headers = { "Authorization" => nil }
    service = AuthorizeApiRequest.new(headers)

    assert_raises ExceptionHandler::MissingToken do
      service.call
    end
  end

  test "should raise InvalidToken for malformed token" do
    headers = { "Authorization" => "Bearer invalid.token.here" }
    service = AuthorizeApiRequest.new(headers)

    assert_raises ExceptionHandler::InvalidToken do
      service.call
    end
  end

  test "should raise InvalidToken for expired token" do
    expired_payload = @user.to_token_payload.merge(exp: 1.hour.ago.to_i)
    expired_token = JWT.encode(expired_payload, Auth::JwtService::SECRET_KEY)
    headers = { "Authorization" => "Bearer #{expired_token}" }
    service = AuthorizeApiRequest.new(headers)

    assert_raises ExceptionHandler::InvalidToken do
      service.call
    end
  end

  test "should raise InvalidToken when user does not exist" do
    non_existent_user_payload = { sub: 99999, email: "ghost@example.com", name: "Ghost User" }
    token = Auth::JwtService.encode(non_existent_user_payload)
    headers = { "Authorization" => "Bearer #{token}" }
    service = AuthorizeApiRequest.new(headers)

    exception = assert_raises ExceptionHandler::InvalidToken do
      service.call
    end

    assert_includes exception.message, Message.invalid_token
    assert_includes exception.message, "Couldn't find User"
  end

  test "should extract token from Authorization header with Bearer prefix" do
    service = AuthorizeApiRequest.new(@headers_with_valid_token)
    result = service.call

    assert_equal @user, result[:user]
  end

  test "should work with Authorization header without Bearer prefix" do
    headers = { "Authorization" => @valid_token }
    service = AuthorizeApiRequest.new(headers)
    result = service.call

    assert_equal @user, result[:user]
  end

  test "should handle Authorization header with multiple spaces" do
    headers = { "Authorization" => "Bearer    #{@valid_token}" }
    service = AuthorizeApiRequest.new(headers)
    result = service.call

    assert_equal @user, result[:user]
  end

  test "should be case sensitive for Authorization header key" do
    headers = { "authorization" => "Bearer #{@valid_token}" }
    service = AuthorizeApiRequest.new(headers)

    assert_raises ExceptionHandler::MissingToken do
      service.call
    end
  end

  test "should memoize user lookup" do
    service = AuthorizeApiRequest.new(@headers_with_valid_token)

    # Call multiple times - should work without errors
    result1 = service.call
    result2 = service.call

    assert_equal @user, result1[:user]
    assert_equal @user, result2[:user]
  end

  test "should memoize decoded token" do
    service = AuthorizeApiRequest.new(@headers_with_valid_token)

    # Access decoded token multiple times indirectly through user lookup
    result1 = service.call
    result2 = service.call

    # Should work without errors, indicating memoization
    assert_equal @user, result1[:user]
    assert_equal @user, result2[:user]
  end

  test "should handle token with different user attributes" do
    different_user = users(:jane)
    token = Auth::JwtService.encode(different_user.to_token_payload)
    headers = { "Authorization" => "Bearer #{token}" }
    service = AuthorizeApiRequest.new(headers)
    result = service.call

    assert_equal different_user, result[:user]
    assert_equal different_user.email, result[:user].email
    assert_equal different_user.name, result[:user].name
  end

  test "should handle empty headers hash" do
    service = AuthorizeApiRequest.new({})

    assert_raises ExceptionHandler::MissingToken do
      service.call
    end
  end

  test "should handle nil headers" do
    service = AuthorizeApiRequest.new(nil)

    assert_raises NoMethodError do
      service.call
    end
  end

  test "should work with string keys in headers" do
    headers = { "Authorization" => "Bearer #{@valid_token}" }
    service = AuthorizeApiRequest.new(headers)
    result = service.call

    assert_equal @user, result[:user]
  end

  test "should work with symbol keys in headers" do
    headers = { Authorization: "Bearer #{@valid_token}" }
    service = AuthorizeApiRequest.new(headers)

    assert_raises ExceptionHandler::MissingToken do
      service.call
    end
  end

  test "should raise InvalidToken with descriptive message for database errors" do
    # Create token for user that will be deleted
    user_to_delete = User.create!(name: "Temp User", email: "temp@example.com", password: "password123")
    token = Auth::JwtService.encode(user_to_delete.to_token_payload)
    user_to_delete.destroy!

    headers = { "Authorization" => "Bearer #{token}" }
    service = AuthorizeApiRequest.new(headers)

    exception = assert_raises ExceptionHandler::InvalidToken do
      service.call
    end

    assert_includes exception.message, Message.invalid_token
  end
end
