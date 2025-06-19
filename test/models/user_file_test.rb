require "test_helper"

class UserFileTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.jpg",
      content_type: "image/jpeg",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert user_file.valid?
  end

  test "should require user" do
    user_file = UserFile.new(
      filename: "test.jpg",
      content_type: "image/jpeg",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert_includes user_file.errors[:user], "must exist"
  end

  test "should require filename" do
    user_file = UserFile.new(
      user: users(:john),
      content_type: "image/jpeg",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert_includes user_file.errors[:filename], "can't be blank"
  end

  test "should require content_type" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.jpg",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert_includes user_file.errors[:content_type], "can't be blank"
  end

  test "should require file_size" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.jpg",
      content_type: "image/jpeg",
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert_includes user_file.errors[:file_size], "can't be blank"
  end

  test "should not require uploaded_at on create" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.jpg",
      content_type: "image/jpeg",
      file_size: 1024
    )
    assert user_file.valid?
  end

  test "should validate filename length" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "",
      content_type: "image/jpeg",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert_includes user_file.errors[:filename], "is too short (minimum is 1 character)"

    user_file.filename = "a" * 256
    assert_not user_file.valid?
    assert_includes user_file.errors[:filename], "is too long (maximum is 255 characters)"
  end

  test "should validate file_size is positive" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.jpg",
      content_type: "image/jpeg",
      file_size: 0,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert_includes user_file.errors[:file_size], "must be greater than 0"
  end

  test "should validate file_size is within limit" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.jpg",
      content_type: "image/jpeg",
      file_size: 3.megabytes,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert_includes user_file.errors[:file_size], "must be less than or equal to 2097152"
  end

  test "should validate allowed content types" do
    allowed_types = [
      "image/jpeg", "image/jpg", "image/png", "image/gif", "image/svg+xml",
      "text/plain", "text/markdown", "text/x-markdown", "application/x-markdown",
      "text/x-web-markdown", "text/csv", "application/csv", "application/octet-stream"
    ]

    allowed_types.each do |content_type|
      user_file = UserFile.new(
        user: users(:john),
        filename: "test.txt",
        content_type: content_type,
        file_size: 1024,
        uploaded_at: Time.current
      )
      assert user_file.valid?, "#{content_type} should be allowed"
    end
  end

  test "should reject disallowed content types" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.exe",
      content_type: "application/exe",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert user_file.errors[:content_type].any? { |error| error.include?("is not supported") }
  end

  test "should validate file extension for octet-stream" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.exe",
      content_type: "application/octet-stream",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert user_file.errors[:filename].any? { |error| error.include?("extension .exe is not supported") }
  end

  test "should allow valid extensions for octet-stream" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.txt",
      content_type: "application/octet-stream",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert user_file.valid?
  end

  test "should validate filename format" do
    invalid_filenames = [
      "file<name>.txt",
      "file|name.txt",
      "file?name.txt",
      "file*name.txt"
    ]

    invalid_filenames.each do |filename|
      user_file = UserFile.new(
        user: users(:john),
        filename: filename,
        content_type: "text/plain",
        file_size: 1024,
        uploaded_at: Time.current
      )
      assert_not user_file.valid?, "#{filename} should be invalid"
      assert user_file.errors[:filename].any? { |error| error.include?("contains invalid characters") }
    end
  end

  test "should reject reserved system names" do
    reserved_names = %w[CON.txt PRN.txt AUX.txt NUL.txt COM1.txt]

    reserved_names.each do |filename|
      user_file = UserFile.new(
        user: users(:john),
        filename: filename,
        content_type: "text/plain",
        file_size: 1024,
        uploaded_at: Time.current
      )
      assert_not user_file.valid?, "#{filename} should be invalid"
      assert_includes user_file.errors[:filename], "uses a reserved system name"
    end
  end

  test "should validate file extension matches allowed types" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.exe",
      content_type: "text/plain",
      file_size: 1024,
      uploaded_at: Time.current
    )
    assert_not user_file.valid?
    assert user_file.errors[:filename].any? { |error| error.include?("extension .exe is not supported") }
  end

  test "should automatically set uploaded_at on create" do
    user_file = UserFile.new(
      user: users(:john),
      filename: "test.txt",
      content_type: "text/plain",
      file_size: 1024
    )

    user_file.save!
    assert_not_nil user_file.uploaded_at
    assert user_file.uploaded_at <= Time.current
  end

  test "should identify image files correctly" do
    image_file = user_files(:image_file)
    text_file = user_files(:text_file)

    assert image_file.image?
    assert_not text_file.image?
  end

  test "should identify text files correctly" do
    text_file = user_files(:text_file)
    csv_file = user_files(:csv_file)
    markdown_file = user_files(:markdown_file)
    image_file = user_files(:image_file)

    assert text_file.text?
    assert csv_file.text?
    assert markdown_file.text?
    assert_not image_file.text?
  end

  test "should return correct file extension" do
    user_file = user_files(:image_file)
    assert_equal ".jpg", user_file.file_extension
  end

  test "should return human readable file size" do
    small_file = UserFile.new(file_size: 512)
    assert_equal "512.0 B", small_file.human_readable_size

    kb_file = UserFile.new(file_size: 1536)
    assert_equal "1.5 KB", kb_file.human_readable_size

    mb_file = UserFile.new(file_size: 1572864)
    assert_equal "1.5 MB", mb_file.human_readable_size
  end

  test "should sanitize filename" do
    user_file = UserFile.new

    assert_equal "testfile.txt", user_file.sanitize_filename("test<>file.txt")
    assert_equal "normal_file.txt", user_file.sanitize_filename("normal_file.txt")
    assert_equal "file with spaces.txt", user_file.sanitize_filename("file with spaces.txt")
  end

  test "should rename file preserving extension" do
    user_file = user_files(:image_file)
    user_file.rename_to("new_name")

    assert_equal "new_name.jpg", user_file.filename
  end

  test "should rename file with new extension if provided" do
    user_file = user_files(:image_file)
    user_file.rename_to("new_name.png")

    assert_equal "new_name.png", user_file.filename
  end

  test "should scope recent files" do
    recent_files = UserFile.recent
    assert_equal user_files(:large_image), recent_files.first
  end

  test "should scope by content type" do
    image_files = UserFile.by_type("image/jpeg")
    assert_includes image_files, user_files(:image_file)
    assert_not_includes image_files, user_files(:text_file)
  end
end
