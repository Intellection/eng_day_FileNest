#!/usr/bin/env ruby
# Comprehensive test script for FileNest application
# This script tests all major functionality of the FileNest application

require 'net/http'
require 'json'
require 'uri'
require 'tempfile'

class FileNestTester
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
    @token = nil
    @user = nil
    @uploaded_files = []
  end

  def run_all_tests
    puts "🚀 Starting FileNest comprehensive test suite..."
    puts "Base URL: #{@base_url}"
    puts "=" * 60

    # Test basic connectivity
    test_health_check

    # Test authentication
    test_user_registration
    test_user_login
    test_invalid_login

    # Test file operations
    test_file_upload_text
    test_file_upload_image
    test_file_upload_markdown
    test_file_upload_csv
    test_file_list
    test_file_download
    test_file_delete
    test_invalid_file_upload

    # Test security
    test_unauthorized_access
    test_file_ownership

    # Cleanup
    cleanup_test_files

    puts "=" * 60
    puts "✅ All tests completed successfully!"
    puts "FileNest is ready for production use."
  end

  private

  def test_health_check
    puts "\n🔍 Testing health check endpoint..."

    response = make_request('/health', 'GET')

    if response.code == '200'
      data = JSON.parse(response.body)
      puts "✅ Health check passed"
      puts "   Status: #{data['status']}"
      puts "   Service: #{data['service']}"
      puts "   Version: #{data['version']}"
      puts "   Database: #{data['database']}"
      puts "   Storage: #{data['storage']}"
    else
      raise "Health check failed with status #{response.code}"
    end
  end

  def test_user_registration
    puts "\n👤 Testing user registration..."

    user_data = {
      name: "Test User #{Time.now.to_i}",
      email: "test#{Time.now.to_i}@example.com",
      password: "password123"
    }

    response = make_request('/auth/register', 'POST', user_data)

    if response.code == '201'
      data = JSON.parse(response.body)
      @token = data['token']
      @user = data['user']
      puts "✅ User registration successful"
      puts "   User: #{@user['name']} (#{@user['email']})"
      puts "   Token received: #{@token[0..20]}..."
    else
      raise "User registration failed with status #{response.code}: #{response.body}"
    end
  end

  def test_user_login
    puts "\n🔐 Testing user login..."

    login_data = {
      email: @user['email'],
      password: "password123"
    }

    response = make_request('/auth/login', 'POST', login_data)

    if response.code == '200'
      data = JSON.parse(response.body)
      puts "✅ User login successful"
      puts "   Token refreshed: #{data['token'][0..20]}..."
    else
      raise "User login failed with status #{response.code}: #{response.body}"
    end
  end

  def test_invalid_login
    puts "\n❌ Testing invalid login..."

    login_data = {
      email: "nonexistent@example.com",
      password: "wrongpassword"
    }

    response = make_request('/auth/login', 'POST', login_data)

    if response.code == '401'
      puts "✅ Invalid login correctly rejected"
    else
      raise "Invalid login should have been rejected with 401, got #{response.code}"
    end
  end

  def test_file_upload_text
    puts "\n📄 Testing text file upload..."

    content = "Hello from FileNest!\nThis is a test text file.\nCurrent time: #{Time.now}"
    file = create_temp_file('test.txt', content)

    response = upload_file(file)

    if response.code == '201'
      data = JSON.parse(response.body)
      @uploaded_files << data['file']
      puts "✅ Text file uploaded successfully"
      puts "   File ID: #{data['file']['id']}"
      puts "   Filename: #{data['file']['filename']}"
      puts "   Size: #{data['file']['human_readable_size']}"
      puts "   Type: #{data['file']['content_type']}"
    else
      raise "Text file upload failed with status #{response.code}: #{response.body}"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_file_upload_image
    puts "\n🖼️ Testing image file upload..."

    # Create a minimal PNG file (1x1 pixel)
    png_content = "\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xDE\x00\x00\x00\tpHYs\x00\x00\x0B\x13\x00\x00\x0B\x13\x01\x00\x9A\x9C\x18\x00\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xDB\x00\x00\x00\x00IEND\xAEB`\x82"
    file = create_temp_file('test.png', png_content, binary: true)

    response = upload_file(file)

    if response.code == '201'
      data = JSON.parse(response.body)
      @uploaded_files << data['file']
      puts "✅ Image file uploaded successfully"
      puts "   File ID: #{data['file']['id']}"
      puts "   Filename: #{data['file']['filename']}"
      puts "   Size: #{data['file']['human_readable_size']}"
      puts "   Is Image: #{data['file']['is_image']}"
    else
      raise "Image file upload failed with status #{response.code}: #{response.body}"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_file_upload_markdown
    puts "\n📝 Testing Markdown file upload..."

    content = <<~MARKDOWN
      # Test Markdown File

      This is a **test** markdown file for FileNest.

      ## Features
      - File upload
      - Authentication
      - Secure storage

      Generated at: #{Time.now}
    MARKDOWN

    file = create_temp_file('test.md', content)

    response = upload_file(file)

    if response.code == '201'
      data = JSON.parse(response.body)
      @uploaded_files << data['file']
      puts "✅ Markdown file uploaded successfully"
      puts "   File ID: #{data['file']['id']}"
      puts "   Filename: #{data['file']['filename']}"
      puts "   Is Text: #{data['file']['is_text']}"
    else
      raise "Markdown file upload failed with status #{response.code}: #{response.body}"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_file_upload_csv
    puts "\n📊 Testing CSV file upload..."

    content = <<~CSV
      name,email,role,created_at
      John Doe,john@example.com,user,#{Time.now}
      Jane Smith,jane@example.com,admin,#{Time.now}
      Bob Johnson,bob@example.com,user,#{Time.now}
    CSV

    file = create_temp_file('test.csv', content)

    response = upload_file(file)

    if response.code == '201'
      data = JSON.parse(response.body)
      @uploaded_files << data['file']
      puts "✅ CSV file uploaded successfully"
      puts "   File ID: #{data['file']['id']}"
      puts "   Filename: #{data['file']['filename']}"
      puts "   Is Text: #{data['file']['is_text']}"
    else
      raise "CSV file upload failed with status #{response.code}: #{response.body}"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_file_list
    puts "\n📋 Testing file listing..."

    response = make_request('/files', 'GET', nil, headers: auth_headers)

    if response.code == '200'
      data = JSON.parse(response.body)
      puts "✅ File listing successful"
      puts "   Total files: #{data['total_count']}"
      puts "   Total size: #{data['human_readable_total_size']}"
      puts "   Files uploaded in this test: #{@uploaded_files.length}"

      if data['files'].length >= @uploaded_files.length
        puts "   ✅ All uploaded files are listed"
      else
        raise "Not all uploaded files are listed"
      end
    else
      raise "File listing failed with status #{response.code}: #{response.body}"
    end
  end

  def test_file_download
    puts "\n📥 Testing file download..."

    return puts "⚠️  Skipping download test - no files uploaded" if @uploaded_files.empty?

    file = @uploaded_files.first
    response = make_request("/files/#{file['id']}/download", 'GET', nil, headers: auth_headers)

    if response.code == '302' || response.code == '200'
      puts "✅ File download successful"
      puts "   File ID: #{file['id']}"
      puts "   Response code: #{response.code}"

      if response.code == '302'
        puts "   Redirected to: #{response['Location']}"
      end
    else
      raise "File download failed with status #{response.code}: #{response.body}"
    end
  end

  def test_file_delete
    puts "\n🗑️ Testing file deletion..."

    return puts "⚠️  Skipping delete test - no files to delete" if @uploaded_files.empty?

    file = @uploaded_files.pop
    response = make_request("/files/#{file['id']}", 'DELETE', nil, headers: auth_headers)

    if response.code == '200'
      puts "✅ File deletion successful"
      puts "   Deleted file ID: #{file['id']}"
      puts "   Filename: #{file['filename']}"
    else
      raise "File deletion failed with status #{response.code}: #{response.body}"
    end
  end

  def test_invalid_file_upload
    puts "\n🚫 Testing invalid file upload..."

    # Try to upload an unsupported file type
    content = "MZ\x90\x00"  # Minimal executable header
    file = create_temp_file('test.exe', content, binary: true)

    response = upload_file(file)

    if response.code == '422'
      puts "✅ Invalid file type correctly rejected"
      data = JSON.parse(response.body)
      puts "   Error: #{data['message']}"
    else
      raise "Invalid file upload should have been rejected with 422, got #{response.code}"
    end
  ensure
    file&.close
    file&.unlink
  end

  def test_unauthorized_access
    puts "\n🔒 Testing unauthorized access..."

    # Try to access files without token
    response = make_request('/files', 'GET')

    if response.code == '401'
      puts "✅ Unauthorized access correctly blocked"
    else
      raise "Unauthorized access should have been blocked with 401, got #{response.code}"
    end
  end

  def test_file_ownership
    puts "\n👥 Testing file ownership security..."

    return puts "⚠️  Skipping ownership test - no files available" if @uploaded_files.empty?

    # Create another user
    other_user_data = {
      name: "Other User #{Time.now.to_i}",
      email: "other#{Time.now.to_i}@example.com",
      password: "password123"
    }

    response = make_request('/auth/register', 'POST', other_user_data)

    if response.code == '201'
      other_data = JSON.parse(response.body)
      other_token = other_data['token']

      # Try to access first user's file with second user's token
      file = @uploaded_files.first
      response = make_request("/files/#{file['id']}", 'GET', nil,
                            headers: { 'Authorization' => "Bearer #{other_token}" })

      if response.code == '403'
        puts "✅ File ownership security working correctly"
      else
        raise "File ownership should have been protected with 403, got #{response.code}"
      end
    else
      puts "⚠️  Could not create second user for ownership test"
    end
  end

  def cleanup_test_files
    puts "\n🧹 Cleaning up test files..."

    deleted_count = 0
    @uploaded_files.each do |file|
      response = make_request("/files/#{file['id']}", 'DELETE', nil, headers: auth_headers)
      if response.code == '200'
        deleted_count += 1
      end
    end

    puts "✅ Cleaned up #{deleted_count} test files"
  end

  def create_temp_file(filename, content, binary: false)
    file = Tempfile.new([File.basename(filename, '.*'), File.extname(filename)])
    if binary
      file.binmode
      file.write(content)
    else
      file.write(content)
    end
    file.rewind
    file
  end

  def upload_file(file)
    uri = URI("#{@base_url}/upload")

    boundary = "----FileNestTestBoundary#{Time.now.to_i}"
    post_body = []
    post_body << "--#{boundary}\r\n"
    post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{File.basename(file.path)}\"\r\n"
    post_body << "Content-Type: application/octet-stream\r\n"
    post_body << "\r\n"
    post_body << file.read
    post_body << "\r\n--#{boundary}--\r\n"

    file.rewind

    request = Net::HTTP::Post.new(uri)
    request.body = post_body.join
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request['Authorization'] = "Bearer #{@token}" if @token

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.request(request)
  end

  def make_request(path, method, data = nil, headers: {})
    uri = URI("#{@base_url}#{path}")

    request = case method.upcase
              when 'GET'
                Net::HTTP::Get.new(uri)
              when 'POST'
                Net::HTTP::Post.new(uri)
              when 'DELETE'
                Net::HTTP::Delete.new(uri)
              else
                raise "Unsupported HTTP method: #{method}"
              end

    if data
      request.body = data.to_json
      request['Content-Type'] = 'application/json'
    end

    headers.each { |key, value| request[key] = value }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 10
    http.request(request)
  end

  def auth_headers
    @token ? { 'Authorization' => "Bearer #{@token}" } : {}
  end
end

# Run the tests
if __FILE__ == $0
  base_url = ARGV[0] || 'http://localhost:3000'

  begin
    tester = FileNestTester.new(base_url)
    tester.run_all_tests
  rescue => e
    puts "\n❌ Test failed: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end
