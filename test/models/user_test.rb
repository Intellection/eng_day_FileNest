require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user = User.new(
      name: "Test User",
      email: "test@example.com",
      password: "password123"
    )
    assert user.valid?
  end

  test "should require name" do
    user = User.new(
      email: "test@example.com",
      password: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should require email" do
    user = User.new(
      name: "Test User",
      password: "password123"
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require password on create" do
    user = User.new(
      name: "Test User",
      email: "test@example.com"
    )
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should require password to be at least 6 characters" do
    user = User.new(
      name: "Test User",
      email: "test@example.com",
      password: "12345"
    )
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "should require unique email" do
    user1 = User.create!(
      name: "User One",
      email: "test@example.com",
      password: "password123"
    )

    user2 = User.new(
      name: "User Two",
      email: "test@example.com",
      password: "password123"
    )

    assert_not user2.valid?
    assert_includes user2.errors[:email], "has already been taken"
  end

  test "should be case insensitive for email uniqueness" do
    user1 = User.create!(
      name: "User One",
      email: "test@example.com",
      password: "password123"
    )

    user2 = User.new(
      name: "User Two",
      email: "TEST@EXAMPLE.COM",
      password: "password123"
    )

    assert_not user2.valid?
    assert_includes user2.errors[:email], "has already been taken"
  end

  test "should downcase email before saving" do
    user = User.create!(
      name: "Test User",
      email: "TEST@EXAMPLE.COM",
      password: "password123"
    )

    assert_equal "test@example.com", user.email
  end

  test "should authenticate with correct password" do
    user = users(:john)
    assert user.authenticate("password123")
  end

  test "should not authenticate with incorrect password" do
    user = users(:john)
    assert_not user.authenticate("wrongpassword")
  end

  test "should have many user_files" do
    user = users(:john)
    assert_respond_to user, :user_files
    assert_equal 2, user.user_files.count
  end

  test "should destroy associated user_files when destroyed" do
    user = users(:john)
    user_files_count = user.user_files.count

    assert_difference 'UserFile.count', -user_files_count do
      user.destroy
    end
  end

  test "should generate token payload" do
    user = users(:john)
    payload = user.to_token_payload

    assert_equal user.id, payload[:sub]
    assert_equal user.email, payload[:email]
    assert_equal user.name, payload[:name]
  end

  test "should not require password on update if not changing it" do
    user = users(:john)
    user.name = "Updated Name"

    assert user.valid?
    assert user.save
  end

  test "should validate password length on update if changing it" do
    user = users(:john)
    user.password = "123"

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end
end
