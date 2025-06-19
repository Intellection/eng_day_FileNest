require "test_helper"

class Auth::JwtServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @payload = @user.to_token_payload
  end

  test "should encode payload into JWT token" do
    token = Auth::JwtService.encode(@payload)

    assert_not_nil token
    assert_instance_of String, token
    assert token.length > 0
    # JWT tokens have 3 parts separated by dots
    assert_equal 3, token.split('.').length
  end

  test "should encode payload with custom expiration" do
    custom_exp = 1.hour.from_now
    token = Auth::JwtService.encode(@payload, custom_exp)

    decoded = Auth::JwtService.decode(token)
    assert_equal custom_exp.to_i, decoded[:exp]
  end

  test "should encode payload with default 24 hour expiration" do
    token = Auth::JwtService.encode(@payload)
    decoded = Auth::JwtService.decode(token)

    # Check that expiration is approximately 24 hours from now (within 1 minute tolerance)
    expected_exp = 24.hours.from_now.to_i
    assert_in_delta expected_exp, decoded[:exp], 60
  end

  test "should decode valid JWT token" do
    token = Auth::JwtService.encode(@payload)
    decoded = Auth::JwtService.decode(token)

    assert_instance_of ActiveSupport::HashWithIndifferentAccess, decoded
    assert_equal @payload[:sub], decoded[:sub]
    assert_equal @payload[:email], decoded[:email]
    assert_equal @payload[:name], decoded[:name]
    assert decoded[:exp].present?
  end

  test "should raise InvalidToken for malformed token" do
    invalid_token = "invalid.token.here"

    assert_raises ExceptionHandler::InvalidToken do
      Auth::JwtService.decode(invalid_token)
    end
  end

  test "should raise InvalidToken for token with wrong signature" do
    # Create token with different secret
    wrong_secret_token = JWT.encode(@payload, "wrong_secret")

    assert_raises ExceptionHandler::InvalidToken do
      Auth::JwtService.decode(wrong_secret_token)
    end
  end

  test "should raise InvalidToken for expired token" do
    expired_payload = @payload.merge(exp: 1.hour.ago.to_i)
    expired_token = JWT.encode(expired_payload, Auth::JwtService::SECRET_KEY)

    assert_raises ExceptionHandler::InvalidToken do
      Auth::JwtService.decode(expired_token)
    end
  end

  test "should handle empty token" do
    assert_raises ExceptionHandler::InvalidToken do
      Auth::JwtService.decode("")
    end
  end

  test "should handle nil token" do
    assert_raises ExceptionHandler::InvalidToken do
      Auth::JwtService.decode(nil)
    end
  end

  test "should use Rails secret key base" do
    expected_secret = Rails.application.credentials.secret_key_base.to_s
    assert_equal expected_secret, Auth::JwtService::SECRET_KEY
  end

  test "encoded token should be decodable" do
    original_data = {
      user_id: 123,
      email: "test@example.com",
      role: "admin",
      permissions: ["read", "write"]
    }

    token = Auth::JwtService.encode(original_data)
    decoded_data = Auth::JwtService.decode(token)

    assert_equal original_data[:user_id], decoded_data[:user_id]
    assert_equal original_data[:email], decoded_data[:email]
    assert_equal original_data[:role], decoded_data[:role]
    assert_equal original_data[:permissions], decoded_data[:permissions]
  end

  test "should preserve data types in encode/decode cycle" do
    complex_payload = {
      id: 42,
      active: true,
      balance: 99.99,
      tags: ["ruby", "rails"],
      metadata: { created_by: "system" }
    }

    token = Auth::JwtService.encode(complex_payload)
    decoded = Auth::JwtService.decode(token)

    assert_equal 42, decoded[:id]
    assert_equal true, decoded[:active]
    assert_equal 99.99, decoded[:balance]
    assert_equal ["ruby", "rails"], decoded[:tags]
    assert_equal({ "created_by" => "system" }, decoded[:metadata])
  end
end
