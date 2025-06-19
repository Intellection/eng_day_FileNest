require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @valid_attributes = {
      name: "Test User",
      email: "test@example.com",
      password: "password123"
    }
  end

  test "should create user with valid attributes" do
    user = User.new(@valid_attributes)
    assert user.valid?
    assert user.save
  end

  test "should require name" do
    user = User.new(@valid_attributes.except(:name))
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should require email" do
    user = User.new(@valid_attributes.except(:email))
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require password" do
    user = User.new(@valid_attributes.except(:password))
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "should require valid email format" do
    invalid_emails = ["invalid", "test@", "@example.com"]

    invalid_emails.each do |email|
      user = User.new(@valid_attributes.merge(email: email))
      assert_not user.valid?, "#{email} should be invalid"
      assert_includes user.errors[:email], "is invalid"
    end
  end

  test "should accept valid email formats" do
    valid_emails = ["test@example.com", "user.name@example.co.uk", "test+tag@example.org"]

    valid_emails.each do |email|
      user = User.new(@valid_attributes.merge(email: email))
      assert user.valid?, "#{email} should be valid"
    end
  end

  test "should require unique email" do
    user1 = User.create!(@valid_attributes)
    user2 = User.new(@valid_attributes)

    assert_not user2.valid?
    assert_includes user2.errors[:email], "has already been taken"
  end

  test "should require password minimum length" do
    user = User.new(@valid_attributes.merge(password: "123"))
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 6 characters)"
  end

  test "should hash password with bcrypt" do
    user = User.create!(@valid_attributes)
    assert_not_equal @valid_attributes[:password], user.password_digest
    assert user.authenticate(@valid_attributes[:password])
  end

  test "should authenticate with correct password" do
    user = User.create!(@valid_attributes)
    assert user.authenticate(@valid_attributes[:password])
  end

  test "should not authenticate with incorrect password" do
    user = User.create!(@valid_attributes)
    assert_not user.authenticate("wrongpassword")
  end

  test "should have many user_files" do
    user = User.create!(@valid_attributes)
    assert_respond_to user, :user_files
    assert_kind_of ActiveRecord::Associations::CollectionProxy, user.user_files
  end

  test "should destroy associated user_files when user is destroyed" do
    user = User.create!(@valid_attributes)
    user_file = user.user_files.create!(
      filename: "test.txt",
      content_type: "text/plain",
      file_size: 100,
      uploaded_at: Time.current
    )

    assert_difference('UserFile.count', -1) do
      user.destroy
    end
  end

  test "should normalize email to lowercase" do
    user = User.create!(@valid_attributes.merge(email: "TEST@EXAMPLE.COM"))
    assert_equal "test@example.com", user.email
  end

  test "should strip whitespace from name and email" do
    user = User.create!(@valid_attributes.merge(
      name: "  Test User  ",
      email: "  test2@example.com  "
    ))

    assert_equal "Test User", user.name
    assert_equal "test2@example.com", user.email
  end

  test "should validate name length" do
    user = User.new(@valid_attributes.merge(name: "a" * 101))
    assert_not user.valid?
    assert_includes user.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "should validate email length" do
    long_email = "a" * 250 + "@example.com"
    user = User.new(@valid_attributes.merge(email: long_email))
    assert_not user.valid?
    assert_includes user.errors[:email], "is too long (maximum is 255 characters)"
  end

  test "should return user stats" do
    user = User.create!(@valid_attributes)

    # Create some test files
    user.user_files.create!(
      filename: "test1.txt",
      content_type: "text/plain",
      file_size: 100,
      uploaded_at: Time.current
    )

    user.user_files.create!(
      filename: "test2.jpg",
      content_type: "image/jpeg",
      file_size: 2000,
      uploaded_at: Time.current
    )

    stats = user.file_stats
    assert_equal 2, stats[:total_files]
    assert_equal 2100, stats[:total_size]
    assert stats[:human_readable_size].present?
  end

  test "should handle empty stats for new user" do
    user = User.create!(@valid_attributes)
    stats = user.file_stats

    assert_equal 0, stats[:total_files]
    assert_equal 0, stats[:total_size]
    assert_equal "0 B", stats[:human_readable_size]
  end
end
