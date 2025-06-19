require "test_helper"

class FilesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      name: "Test User",
      email: "test@example.com",
      password: "password123"
    )
    @other_user = User.create!(
      name: "Other User",
      email: "other@example.com",
      password: "password123"
    )
    @token = Auth::JwtService.encode(sub: @user.id, email: @user.email, name: @user.name)
    @auth_headers = { "Authorization" => "Bearer #{@token}" }

    @user_file = @user.user_files.create!(
      filename: "test.txt",
      content_type: "text/plain",
      file_size: 100,
      uploaded_at: Time.current
    )

    @other_user_file = @other_user.user_files.create!(
      filename: "other.txt",
      content_type: "text/plain",
      file_size: 200,
      uploaded_at: Time.current
    )
  end

  test "should list user files with authentication" do
    get files_path, headers: @auth_headers

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["files"].length
    assert_equal @user_file.filename, json_response["files"].first["filename"]
    assert_equal 1, json_response["total_count"]
    assert_equal 100, json_response["total_size"]
  end

  test "should not list files without authentication" do
    get files_path

    assert_response :unauthorized
  end

  test "should only list current user's files" do
    get files_path, headers: @auth_headers

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should only see current user's files
    assert_equal 1, json_response["files"].length
    assert_equal @user_file.filename, json_response["files"].first["filename"]

    # Should not see other user's files
    other_file_ids = json_response["files"].map { |f| f["id"] }
    assert_not_includes other_file_ids, @other_user_file.id
  end

  test "should show specific file with authentication" do
    get file_path(@user_file), headers: @auth_headers

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal @user_file.id, json_response["file"]["id"]
    assert_equal @user_file.filename, json_response["file"]["filename"]
    assert_equal @user_file.content_type, json_response["file"]["content_type"]
  end

  test "should not show file without authentication" do
    get file_path(@user_file)

    assert_response :unauthorized
  end

  test "should not show other user's file" do
    get file_path(@other_user_file), headers: @auth_headers

    assert_response :forbidden
  end

  test "should return 404 for non-existent file" do
    get file_path(id: 999999), headers: @auth_headers

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "not found"
  end

  test "should download file with authentication" do
    # Mock file attachment
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("test content"),
      filename: @user_file.filename,
      content_type: @user_file.content_type
    )
    @user_file.file.attach(blob)

    get download_file_path(@user_file), headers: @auth_headers

    assert_response :redirect
    assert_match /rails\/active_storage/, response.headers["Location"]
  end

  test "should not download file without authentication" do
    get download_file_path(@user_file)

    assert_response :unauthorized
  end

  test "should not download other user's file" do
    get download_file_path(@other_user_file), headers: @auth_headers

    assert_response :forbidden
  end

  test "should return 404 when downloading file without attachment" do
    get download_file_path(@user_file), headers: @auth_headers

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_includes json_response["message"], "not found"
  end

  test "should delete file with authentication" do
    assert_difference('@user.user_files.count', -1) do
      delete file_path(@user_file), headers: @auth_headers
    end

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal "File deleted successfully", json_response["message"]
  end

  test "should not delete file without authentication" do
    assert_no_difference('@user.user_files.count') do
      delete file_path(@user_file)
    end

    assert_response :unauthorized
  end

  test "should not delete other user's file" do
    assert_no_difference('UserFile.count') do
      delete file_path(@other_user_file), headers: @auth_headers
    end

    assert_response :forbidden
  end

  test "should return 404 when deleting non-existent file" do
    delete file_path(id: 999999), headers: @auth_headers

    assert_response :not_found
  end

  test "should include file metadata in listing" do
    get files_path, headers: @auth_headers

    assert_response :ok
    json_response = JSON.parse(response.body)
    file_data = json_response["files"].first

    assert file_data["id"].present?
    assert file_data["filename"].present?
    assert file_data["content_type"].present?
    assert file_data["file_size"].present?
    assert file_data["human_readable_size"].present?
    assert file_data["uploaded_at"].present?
    assert file_data.key?("is_image")
    assert file_data.key?("is_text")
    assert file_data["file_extension"].present?
  end

  test "should calculate human readable total size" do
    # Create additional files to test size calculation
    @user.user_files.create!(
      filename: "large.txt",
      content_type: "text/plain",
      file_size: 1024,
      uploaded_at: Time.current
    )

    get files_path, headers: @auth_headers

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal 2, json_response["total_count"]
    assert_equal 1124, json_response["total_size"] # 100 + 1024
    assert json_response["human_readable_total_size"].present?
    assert_match /KB/, json_response["human_readable_total_size"]
  end

  test "should return empty files list for new user" do
    new_user = User.create!(
      name: "New User",
      email: "new@example.com",
      password: "password123"
    )
    new_token = Auth::JwtService.encode(sub: new_user.id, email: new_user.email, name: new_user.name)
    new_headers = { "Authorization" => "Bearer #{new_token}" }

    get files_path, headers: new_headers

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_equal 0, json_response["files"].length
    assert_equal 0, json_response["total_count"]
    assert_equal 0, json_response["total_size"]
    assert_equal "0 B", json_response["human_readable_total_size"]
  end

  test "should handle malformed authorization token" do
    malformed_headers = { "Authorization" => "Bearer invalid.token.here" }

    get files_path, headers: malformed_headers

    assert_response :unauthorized
  end

  test "should handle expired token" do
    expired_token = Auth::JwtService.encode(
      { sub: @user.id, email: @user.email, name: @user.name },
      1.hour.ago
    )
    expired_headers = { "Authorization" => "Bearer #{expired_token}" }

    get files_path, headers: expired_headers

    assert_response :unauthorized
  end

  private

  def file_path(file_or_id)
    if file_or_id.is_a?(Hash)
      "/files/#{file_or_id[:id]}"
    else
      "/files/#{file_or_id.respond_to?(:id) ? file_or_id.id : file_or_id}"
    end
  end

  def download_file_path(file)
    "/files/#{file.id}/download"
  end
end
