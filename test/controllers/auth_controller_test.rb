require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user_attributes = {
      name: "Test User",
      email: "test@example.com",
      password: "password123"
    }
  end

  test "should register new user with valid attributes" do
    assert_difference('User.count', 1) do
      post auth_register_path, params: @user_attributes, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert json_response["token"].present?
    assert_equal @user_attributes[:name], json_response["user"]["name"]
    assert_equal @user_attributes[:email], json_response["user"]["email"]
  end

  test "should not register user with invalid email" do
    @user_attributes[:email] = "invalid-email"

    assert_no_difference('User.count') do
      post auth_register_path, params: @user_attributes, as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["message"].present?
  end

  test "should not register user with short password" do
    @user_attributes[:password] = "123"

    assert_no_difference('User.count') do
      post auth_register_path, params: @user_attributes, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "should not register user with duplicate email" do
    # Create first user
    User.create!(@user_attributes)

    assert_no_difference('User.count') do
      post auth_register_path, params: @user_attributes, as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "Email has already been taken"
  end

  test "should login with valid credentials" do
    user = User.create!(@user_attributes)

    post auth_login_path, params: {
      email: @user_attributes[:email],
      password: @user_attributes[:password]
    }, as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert json_response["token"].present?
    assert_equal user.name, json_response["user"]["name"]
    assert_equal user.email, json_response["user"]["email"]
  end

  test "should not login with invalid email" do
    User.create!(@user_attributes)

    post auth_login_path, params: {
      email: "wrong@example.com",
      password: @user_attributes[:password]
    }, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal "Invalid credentials", json_response["message"]
  end

  test "should not login with invalid password" do
    User.create!(@user_attributes)

    post auth_login_path, params: {
      email: @user_attributes[:email],
      password: "wrongpassword"
    }, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert_equal "Invalid credentials", json_response["message"]
  end

  test "should not login with missing credentials" do
    post auth_login_path, params: {}, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)
    assert json_response["message"].present?
  end
end
