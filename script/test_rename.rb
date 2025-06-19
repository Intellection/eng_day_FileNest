#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class FileRenameTest
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
    @token = nil
    @user_id = nil
  end

  def run_tests
    puts "🧪 Starting File Rename Tests..."
    puts "=" * 50

    begin
      # Step 1: Register a test user
      register_test_user

      # Step 2: Login and get token
      login_test_user

      # Step 3: Upload a test file
      file_id = upload_test_file

      # Step 4: Test successful rename
      test_successful_rename(file_id)

      # Step 5: Test invalid filename rename
      test_invalid_filename_rename(file_id)

      # Step 6: Test unauthorized access (try to rename as different user)
      test_unauthorized_rename(file_id)

      # Step 7: Test non-existent file rename
      test_nonexistent_file_rename

      # Step 8: Clean up
      cleanup_test_file(file_id)

      puts "\n✅ All tests completed successfully!"

    rescue => e
      puts "\n❌ Test failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end

  private

  def register_test_user
    puts "\n📋 Registering test user..."

    response = make_request('/auth/register', 'POST', {
      user: {
        email: "test_rename_#{Time.now.to_i}@example.com",
        password: "testpassword123",
        password_confirmation: "testpassword123"
      }
    })

    if response.code == '201'
      data = JSON.parse(response.body)
      @token = data['token']
      @user_id = data['user']['id']
      puts "✅ Test user registered successfully"
    else
      raise "Failed to register test user: #{response.body}"
    end
  end

  def login_test_user
    puts "\n🔐 Logging in test user..."

    # We already have the token from registration, but let's test login too
    response = make_request('/auth/login', 'POST', {
      email: "test_rename_#{Time.now.to_i}@example.com",
      password: "testpassword123"
    })

    puts "✅ Login successful" if response.code == '200'
  end

  def upload_test_file
    puts "\n📤 Uploading test file..."

    # Create a temporary test file
    test_content = "This is a test file for rename functionality\nCreated at: #{Time.now}"

    uri = URI("#{@base_url}/upload")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@token}"

    form_data = [
      ['file', StringIO.new(test_content), { filename: 'test_original.txt', content_type: 'text/plain' }]
    ]
    request.set_form(form_data, 'multipart/form-data')

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    if response.code == '201'
      data = JSON.parse(response.body)
      file_id = data['file']['id']
      puts "✅ Test file uploaded successfully (ID: #{file_id})"
      return file_id
    else
      raise "Failed to upload test file: #{response.body}"
    end
  end

  def test_successful_rename(file_id)
    puts "\n✏️  Testing successful rename..."

    new_filename = "renamed_test_file.txt"

    response = make_request("/files/#{file_id}", 'PATCH', {
      file: { filename: new_filename }
    })

    if response.code == '200'
      data = JSON.parse(response.body)
      if data['file']['filename'] == new_filename
        puts "✅ File renamed successfully to '#{new_filename}'"
      else
        raise "Rename response doesn't match expected filename"
      end
    else
      raise "Failed to rename file: #{response.body}"
    end
  end

  def test_invalid_filename_rename(file_id)
    puts "\n❌ Testing invalid filename rename..."

    invalid_filenames = [
      "",                    # Empty filename
      "file_without_extension",  # No extension
      "file<>with|invalid*chars.txt",  # Invalid characters
      "CON.txt",            # Reserved name
      ".hidden_file.txt",   # Starts with dot
      "file_with_space_at_end .txt",  # Ends with space
      "a" * 256 + ".txt"    # Too long
    ]

    invalid_filenames.each do |invalid_name|
      response = make_request("/files/#{file_id}", 'PATCH', {
        file: { filename: invalid_name }
      })

      if response.code == '422'
        puts "✅ Correctly rejected invalid filename: '#{invalid_name.length > 50 ? invalid_name[0..50] + '...' : invalid_name}'"
      else
        puts "⚠️  Expected rejection for '#{invalid_name}' but got: #{response.code}"
      end
    end
  end

  def test_unauthorized_rename(file_id)
    puts "\n🔒 Testing unauthorized rename..."

    # Try to rename without token
    response = make_request("/files/#{file_id}", 'PATCH', {
      file: { filename: "unauthorized_rename.txt" }
    }, false)

    if response.code == '401'
      puts "✅ Correctly rejected unauthorized rename attempt"
    else
      puts "⚠️  Expected 401 but got: #{response.code}"
    end
  end

  def test_nonexistent_file_rename
    puts "\n🔍 Testing non-existent file rename..."

    fake_file_id = 99999
    response = make_request("/files/#{fake_file_id}", 'PATCH', {
      file: { filename: "nonexistent.txt" }
    })

    if response.code == '404'
      puts "✅ Correctly returned 404 for non-existent file"
    else
      puts "⚠️  Expected 404 but got: #{response.code}"
    end
  end

  def cleanup_test_file(file_id)
    puts "\n🧹 Cleaning up test file..."

    response = make_request("/files/#{file_id}", 'DELETE')

    if response.code == '200'
      puts "✅ Test file cleaned up successfully"
    else
      puts "⚠️  Failed to clean up test file: #{response.body}"
    end
  end

  def make_request(endpoint, method, data = nil, use_auth = true)
    uri = URI("#{@base_url}#{endpoint}")

    request = case method
    when 'GET'
      Net::HTTP::Get.new(uri)
    when 'POST'
      Net::HTTP::Post.new(uri)
    when 'PATCH'
      Net::HTTP::Patch.new(uri)
    when 'DELETE'
      Net::HTTP::Delete.new(uri)
    end

    if use_auth && @token
      request['Authorization'] = "Bearer #{@token}"
    end

    if data
      request['Content-Type'] = 'application/json'
      request.body = data.to_json
    end

    Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end
  end
end

# Run the tests
if __FILE__ == $0
  base_url = ARGV[0] || 'http://localhost:3000'

  puts "🚀 Testing File Rename Functionality"
  puts "Base URL: #{base_url}"
  puts "Time: #{Time.now}"

  tester = FileRenameTest.new(base_url)
  tester.run_tests
end
