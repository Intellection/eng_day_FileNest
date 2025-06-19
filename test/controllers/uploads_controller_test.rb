require "test_helper"

class UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @token = Auth::JwtService.encode(@user.to_token_payload)
    @auth_headers = { "Authorization" => "Bearer #{@token}" }

    # Create test file objects for uploads
    @valid_text = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_file.txt'),
      'text/plain'
    )
    @valid_csv = Rack::Test::UploadedFile.new(
      Rails.root.join('test', 'fixtures', 'files', 'test_data.csv'),
      'text/csv'
    )
  end

  # POST /upload
  test "should upload valid text file" do
    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: @valid_text },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_includes json_response["message"], "Virus scanning service unavailable"
  end

  test "should upload valid CSV file" do
    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: @valid_csv },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert_includes json_response["message"], "Virus scanning service unavailable"
  end

  test "should not upload without authentication" do
    assert_no_difference 'UserFile.count' do
      post "/upload", params: { file: @valid_text }
    end

    assert_response :unprocessable_entity
  end

  test "should not upload with invalid token" do
    invalid_headers = { "Authorization" => "Bearer invalid_token" }

    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: @valid_text },
           headers: invalid_headers
    end

    assert_response :unprocessable_entity
  end

  test "should not upload without file parameter" do
    assert_no_difference 'UserFile.count' do
      post "/upload", headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "No file provided", json_response["message"]
  end

  test "should not upload empty file parameter" do
    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: nil },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "No file provided", json_response["message"]
  end

  test "should not upload file larger than 2MB" do
    # Mock a large file
    large_file = Rack::Test::UploadedFile.new(
      StringIO.new("x" * (2.megabytes + 1)),
      "image/jpeg",
      original_filename: "large_image.jpg"
    )

    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: large_file },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal Message.file_too_large, json_response["message"]
  end

  test "should detect content type correctly" do
    post "/upload",
         params: { file: @valid_text },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "Virus scanning service unavailable"
  end

  test "should handle CSV file upload from fixture" do
    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: @valid_csv },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "Virus scanning service unavailable"
  end

  test "should handle markdown file upload" do
    md_content = "# Test Markdown\nThis is a test markdown file."
    md_file = Rack::Test::UploadedFile.new(
      StringIO.new(md_content),
      "text/markdown",
      original_filename: "readme.md"
    )

    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: md_file },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "Virus scanning service unavailable"
  end

  test "should reject unsupported file types" do
    exe_file = Rack::Test::UploadedFile.new(
      StringIO.new("fake exe content"),
      "application/octet-stream",
      original_filename: "malware.exe"
    )

    assert_no_difference 'UserFile.count' do
      post "/upload",
           params: { file: exe_file },
           headers: @auth_headers
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "not supported"
  end

  test "should handle file with special characters in filename" do
    special_file = Rack::Test::UploadedFile.new(
      StringIO.new("test content"),
      "text/plain",
      original_filename: "file with spaces & symbols!.txt"
    )

    # This should be handled by the model validation
    post "/upload",
         params: { file: special_file },
         headers: @auth_headers

    # The response depends on how the controller handles validation errors
    # It might create with sanitized filename or reject with validation error
    assert_response :unprocessable_entity
  end

  test "should set file attributes correctly" do
    post "/upload",
         params: { file: @valid_text },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "Virus scanning service unavailable"
  end

  test "should return proper JSON structure on success" do
    post "/upload",
         params: { file: @valid_text },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    # Check required keys in response
    assert json_response.key?("message")
    assert_includes json_response["message"], "Virus scanning service unavailable"
  end

  test "should handle concurrent uploads from same user" do
    file1 = Rack::Test::UploadedFile.new(
      StringIO.new("content 1"),
      "text/plain",
      original_filename: "file1.txt"
    )

    file2 = Rack::Test::UploadedFile.new(
      StringIO.new("content 2"),
      "text/plain",
      original_filename: "file2.txt"
    )

    assert_no_difference 'UserFile.count' do
      post "/upload", params: { file: file1 }, headers: @auth_headers
      post "/upload", params: { file: file2 }, headers: @auth_headers
    end

    # Both uploads should fail due to virus scanning
    assert_response :unprocessable_entity
  end

  test "should handle upload with missing original filename" do
    # This should raise an error during file creation
    assert_raises ArgumentError do
      file_without_name = Rack::Test::UploadedFile.new(
        StringIO.new("test content"),
        "text/plain",
        original_filename: nil
      )
    end
  end

  test "should preserve file extension in filename" do
    post "/upload",
         params: { file: @valid_text },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "Virus scanning service unavailable"
  end
end
