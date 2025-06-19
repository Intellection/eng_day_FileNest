require "test_helper"

class UserFileTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123"
    )
    @valid_attributes = {
      user: @user,
      filename: "test.txt",
      content_type: "text/plain",
      file_size: 1024,
      uploaded_at: Time.current
    }
  end

  test "should create user file with valid attributes" do
    user_file = UserFile.new(@valid_attributes)
    assert user_file.valid?
    assert user_file.save
  end

  test "should require filename" do
    user_file = UserFile.new(@valid_attributes.except(:filename))
    assert_not user_file.valid?
    assert_includes user_file.errors[:filename], "can't be blank"
  end

  test "should require content_type" do
    user_file = UserFile.new(@valid_attributes.except(:content_type))
    assert_not user_file.valid?
    assert_includes user_file.errors[:content_type], "can't be blank"
  end

  test "should require file_size" do
    user_file = UserFile.new(@valid_attributes.except(:file_size))
    assert_not user_file.valid?
    assert_includes user_file.errors[:file_size], "can't be blank"
  end

  test "should require user" do
    user_file = UserFile.new(@valid_attributes.except(:user))
    assert_not user_file.valid?
    assert_includes user_file.errors[:user], "must exist"
  end

  test "should validate allowed content types" do
    allowed_types = UserFile::ALLOWED_CONTENT_TYPES

    allowed_types.each do |content_type|
      user_file = UserFile.new(@valid_attributes.merge(content_type: content_type))
      assert user_file.valid?, "#{content_type} should be allowed"
    end
  end

  test "should not allow invalid content types" do
    invalid_types = ["application/pdf", "video/mp4", "audio/mp3"]

    invalid_types.each do |content_type|
      user_file = UserFile.new(@valid_attributes.merge(content_type: content_type))
      assert_not user_file.valid?, "#{content_type} should not be allowed"
    end
  end

  test "should validate file size is positive" do
    user_file = UserFile.new(@valid_attributes.merge(file_size: 0))
    assert_not user_file.valid?
    assert_includes user_file.errors[:file_size], "must be greater than 0"
  end

  test "should validate file size maximum" do
    user_file = UserFile.new(@valid_attributes.merge(file_size: 3.megabytes))
    assert_not user_file.valid?
    assert_includes user_file.errors[:file_size], "must be less than or equal to 2097152"
  end

  test "should identify image files correctly" do
    image_types = ["image/jpeg", "image/png", "image/gif", "image/svg+xml"]

    image_types.each do |content_type|
      user_file = UserFile.new(@valid_attributes.merge(content_type: content_type))
      assert user_file.image?, "#{content_type} should be identified as image"
    end
  end

  test "should identify text files correctly" do
    text_types = ["text/plain", "text/markdown", "text/x-markdown", "text/csv"]

    text_types.each do |content_type|
      user_file = UserFile.new(@valid_attributes.merge(content_type: content_type))
      assert user_file.text?, "#{content_type} should be identified as text"
    end
  end

  test "should not identify non-image files as images" do
    non_image_types = ["text/plain", "text/csv", "application/json"]

    non_image_types.each do |content_type|
      user_file = UserFile.new(@valid_attributes.merge(content_type: content_type))
      assert_not user_file.image?, "#{content_type} should not be identified as image"
    end
  end

  test "should return human readable file size" do
    test_cases = [
      { size: 512, expected: "512.0 B" },
      { size: 1024, expected: "1.0 KB" },
      { size: 1536, expected: "1.5 KB" },
      { size: 1024 * 1024, expected: "1.0 MB" },
      { size: 1024 * 1024 * 1024, expected: "1.0 GB" }
    ]

    test_cases.each do |test_case|
      user_file = UserFile.new(@valid_attributes.merge(file_size: test_case[:size]))
      assert_equal test_case[:expected], user_file.human_readable_size
    end
  end

  test "should extract file extension" do
    test_cases = [
      { filename: "test.txt", expected: ".txt" },
      { filename: "image.PNG", expected: ".png" },
      { filename: "document.md", expected: ".md" },
      { filename: "data.CSV", expected: ".csv" },
      { filename: "noextension", expected: "" }
    ]

    test_cases.each do |test_case|
      user_file = UserFile.new(@valid_attributes.merge(filename: test_case[:filename]))
      assert_equal test_case[:expected], user_file.file_extension
    end
  end

  test "should have recent scope" do
    old_file = @user.user_files.create!(@valid_attributes.merge(
      filename: "old.txt",
      uploaded_at: 1.week.ago
    ))
    new_file = @user.user_files.create!(@valid_attributes.merge(
      filename: "new.txt",
      uploaded_at: Time.current
    ))

    recent_files = UserFile.recent
    assert_equal new_file.id, recent_files.first.id
    assert_equal old_file.id, recent_files.last.id
  end

  test "should belong to user" do
    user_file = UserFile.create!(@valid_attributes)
    assert_equal @user, user_file.user
  end

  test "should have one attached file" do
    user_file = UserFile.create!(@valid_attributes)
    assert_respond_to user_file, :file
  end

  test "should validate octet-stream files have allowed extensions" do
    # Test allowed extensions for octet-stream
    allowed_extensions = UserFile::ALLOWED_FILE_EXTENSIONS

    allowed_extensions.each do |extension|
      filename = "test#{extension}"
      user_file = UserFile.new(@valid_attributes.merge(
        filename: filename,
        content_type: "application/octet-stream"
      ))
      assert user_file.valid?, "#{extension} should be allowed for octet-stream"
    end
  end

  test "should not allow octet-stream with invalid extensions" do
    invalid_extensions = [".exe", ".dll", ".bat", ".sh"]

    invalid_extensions.each do |extension|
      filename = "test#{extension}"
      user_file = UserFile.new(@valid_attributes.merge(
        filename: filename,
        content_type: "application/octet-stream"
      ))
      assert_not user_file.valid?, "#{extension} should not be allowed for octet-stream"
    end
  end

  test "should set uploaded_at automatically" do
    user_file = UserFile.new(@valid_attributes.except(:uploaded_at))
    user_file.save!
    assert user_file.uploaded_at.present?
  end

  test "should validate filename length" do
    long_filename = "a" * 256 + ".txt"
    user_file = UserFile.new(@valid_attributes.merge(filename: long_filename))
    assert_not user_file.valid?
    assert_includes user_file.errors[:filename], "is too long (maximum is 255 characters)"
  end

  test "should handle markdown file variations" do
    markdown_types = [
      "text/markdown",
      "text/x-markdown",
      "application/x-markdown",
      "text/x-web-markdown"
    ]

    markdown_types.each do |content_type|
      user_file = UserFile.new(@valid_attributes.merge(content_type: content_type))
      assert user_file.valid?, "#{content_type} should be allowed"
      assert user_file.text?, "#{content_type} should be identified as text"
    end
  end

  test "should handle CSV file variations" do
    csv_types = ["text/csv", "application/csv"]

    csv_types.each do |content_type|
      user_file = UserFile.new(@valid_attributes.merge(content_type: content_type))
      assert user_file.valid?, "#{content_type} should be allowed"
      assert user_file.text?, "#{content_type} should be identified as text"
    end
  end

  test "should prevent duplicate filenames for same user" do
    UserFile.create!(@valid_attributes)
    duplicate_file = UserFile.new(@valid_attributes)

    assert_not duplicate_file.valid?
    assert_includes duplicate_file.errors[:filename], "has already been taken"
  end

  test "should allow same filename for different users" do
    other_user = User.create!(
      name: "Other User",
      email: "other@example.com",
      password: "password123"
    )

    UserFile.create!(@valid_attributes)
    other_file = UserFile.new(@valid_attributes.merge(user: other_user))

    assert other_file.valid?
  end
end
