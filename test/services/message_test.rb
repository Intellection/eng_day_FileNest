require "test_helper"

class MessageTest < ActiveSupport::TestCase
  test "should return not found message with default record" do
    message = Message.not_found
    assert_equal "Sorry, record not found.", message
  end

  test "should return not found message with custom record" do
    message = Message.not_found("user")
    assert_equal "Sorry, user not found.", message
  end

  test "should return invalid credentials message" do
    message = Message.invalid_credentials
    assert_equal "Invalid credentials", message
  end

  test "should return invalid token message" do
    message = Message.invalid_token
    assert_equal "Invalid token", message
  end

  test "should return missing token message" do
    message = Message.missing_token
    assert_equal "Missing token", message
  end

  test "should return unauthorized message" do
    message = Message.unauthorized
    assert_equal "Unauthorized request", message
  end

  test "should return account created message" do
    message = Message.account_created
    assert_equal "Account created successfully", message
  end

  test "should return account not created message" do
    message = Message.account_not_created
    assert_equal "Account could not be created", message
  end

  test "should return expired token message" do
    message = Message.expired_token
    assert_equal "Sorry, your token has expired. Please login to continue.", message
  end

  test "should return file uploaded message" do
    message = Message.file_uploaded
    assert_equal "File uploaded successfully", message
  end

  test "should return file not uploaded message" do
    message = Message.file_not_uploaded
    assert_equal "File could not be uploaded", message
  end

  test "should return file too large message" do
    message = Message.file_too_large
    assert_equal "File size exceeds 2MB limit", message
  end

  test "should return invalid file type message" do
    message = Message.invalid_file_type
    assert_equal "File type not supported", message
  end

  test "should return file not found message" do
    message = Message.file_not_found
    assert_equal "File not found", message
  end

  test "should return access denied message" do
    message = Message.access_denied
    assert_equal "Access denied. You can only access your own files.", message
  end

  test "all message methods should return strings" do
    message_methods = [
      :invalid_credentials, :invalid_token, :missing_token, :unauthorized,
      :account_created, :account_not_created, :expired_token, :file_uploaded,
      :file_not_uploaded, :file_too_large, :invalid_file_type, :file_not_found,
      :access_denied
    ]

    message_methods.each do |method|
      result = Message.send(method)
      assert_instance_of String, result
      assert result.length > 0, "#{method} should return non-empty string"
    end
  end

  test "not_found should handle various record types" do
    test_cases = [
      ["user", "Sorry, user not found."],
      ["file", "Sorry, file not found."],
      ["document", "Sorry, document not found."],
      ["", "Sorry,  not found."],
      [nil, "Sorry,  not found."]
    ]

    test_cases.each do |record_type, expected|
      result = Message.not_found(record_type)
      assert_equal expected, result
    end
  end
end
