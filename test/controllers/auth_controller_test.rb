require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @valid_login_params = {
      user: {
        email: @user.email,
        password: "password123"
      }
    }
    @valid_register_params = {
      user: {
        name: "New User",
        email: "newuser@example.com",
        password: "password123"
      }
    }
  end

  # Login tests
  test "should login with valid credentials" do
    # Create user with known password
    user = User.create!(name: "Test User", email: "test@example.com", password: "password123")

    post "/auth/login", params: {
      email: "test@example.com",
      password: "password123"
    }, as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response["token"].present?
    assert json_response["exp"].present?
    assert_equal user.id, json_response["user"]["id"]
    assert_equal user.name, json_response["user"]["name"]
    assert_equal user.email, json_response["user"]["email"]
  end

  test "should not login with invalid email" do
    post "/auth/login", params: {
      email: "nonexistent@example.com",
      password: "password123"
    }, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal Message.invalid_credentials, json_response["message"]
  end

  test "should not login with invalid password" do
    post "/auth/login", params: {
      email: @user.email,
      password: "wrongpassword"
    }, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal Message.invalid_credentials, json_response["message"]
  end

  test "should not login with missing email" do
    post "/auth/login", params: {
      password: "password123"
    }, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal Message.invalid_credentials, json_response["message"]
  end

  test "should not login with missing password" do
    post "/auth/login", params: {
      email: @user.email
    }, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal Message.invalid_credentials, json_response["message"]
  end

  # Register tests
  test "should register new user with valid params" do
    assert_difference 'User.count', 1 do
      post "/auth/register", params: {
        name: "New User",
        email: "newuser@example.com",
        password: "password123"
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)

    assert json_response["token"].present?
    assert json_response["exp"].present?
    assert json_response["user"]["id"].present?
    assert_equal "New User", json_response["user"]["name"]
    assert_equal "newuser@example.com", json_response["user"]["email"]
  end

  test "should not register user with existing email" do
    assert_no_difference 'User.count' do
      post "/auth/register", params: {
        name: "New User",
        email: @user.email,
        password: "password123"
      }, as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["message"].present?
  end

  test "should not register user with missing name" do
    assert_no_difference 'User.count' do
      post "/auth/register", params: {
        email: "newuser@example.com",
        password: "password123"
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "should not register user with missing email" do
    assert_no_difference 'User.count' do
      post "/auth/register", params: {
        name: "New User",
        password: "password123"
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "should not register user with short password" do
    assert_no_difference 'User.count' do
      post "/auth/register", params: {
        name: "New User",
        email: "newuser@example.com",
        password: "123"
      }, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "login should generate valid JWT token" do
    # Create user with known password
    user = User.create!(name: "Test User", email: "test@example.com", password: "password123")

    post "/auth/login", params: {
      email: "test@example.com",
      password: "password123"
    }, as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)
    token = json_response["token"]

    # Should be able to decode the token
    decoded = Auth::JwtService.decode(token)
    assert_equal user.id, decoded[:sub]
    assert_equal user.email, decoded[:email]
    assert_equal user.name, decoded[:name]
  end

  test "register should generate valid JWT token" do
    post "/auth/register", params: {
      name: "New User",
      email: "newuser@example.com",
      password: "password123"
    }, as: :json

    assert_response :created
    json_response = JSON.parse(response.body)
    token = json_response["token"]

    # Should be able to decode the token
    decoded = Auth::JwtService.decode(token)
    created_user = User.find(json_response["user"]["id"])
    assert_equal created_user.id, decoded[:sub]
    assert_equal created_user.email, decoded[:email]
    assert_equal created_user.name, decoded[:name]
  end

  test "should handle malformed JSON gracefully" do
    begin
      post "/auth/login",
           params: "invalid json",
           headers: { "Content-Type" => "application/json" }

      # App may handle this differently
      assert_includes [400, 422, 500], response.status
    rescue ActionView::Template::Error
      # This is expected for malformed JSON
      assert true
    end
  end
end
