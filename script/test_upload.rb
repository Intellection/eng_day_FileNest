#!/usr/bin/env ruby

# Test script to verify file uploads work correctly
# Run with: ruby script/test_upload.rb

require 'net/http'
require 'json'
require 'tempfile'
require 'uri'

BASE_URL = 'http://localhost:3000'

def create_test_user
  uri = URI("#{BASE_URL}/auth/register")
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    name: "Test User",
    email: "test#{Time.now.to_i}@example.com",
    password: "password123"
  }.to_json

  response = http.request(request)
  if response.code == '201'
    JSON.parse(response.body)['token']
  else
    puts "Failed to create user: #{response.body}"
    nil
  end
end

def upload_file(token, filename, content)
  uri = URI("#{BASE_URL}/upload")
  http = Net::HTTP.new(uri.host, uri.port)

  # Create a temporary file
  Tempfile.create([File.basename(filename, '.*'), File.extname(filename)]) do |tempfile|
    tempfile.write(content)
    tempfile.rewind

    # Create multipart form data
    boundary = "----WebKitFormBoundary#{Time.now.to_i}"

    post_body = []
    post_body << "--#{boundary}\r\n"
    post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    post_body << "Content-Type: application/octet-stream\r\n"
    post_body << "\r\n"
    post_body << tempfile.read
    post_body << "\r\n--#{boundary}--\r\n"

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request.body = post_body.join

    response = http.request(request)
    {
      code: response.code,
      body: (JSON.parse(response.body) rescue response.body)
    }
  end
end

# Test files
test_files = {
  'test.txt' => 'This is a plain text file for testing.',
  'readme.md' => "# Test Markdown\n\nThis is a **markdown** file with:\n\n- List item 1\n- List item 2\n\n## Code Example\n\n```ruby\nputs 'Hello World'\n```",
  'data.csv' => "name,age,city\nJohn,30,NYC\nJane,25,LA\nBob,35,SF",
  'notes.markdown' => "## Meeting Notes\n\n### Agenda\n1. Review requirements\n2. Discuss implementation\n3. Set timeline\n\n### Action Items\n- [ ] Complete design\n- [ ] Write tests\n- [x] Setup project"
}

puts "File Upload Test Script"
puts "=" * 50

# Check if server is running
begin
  uri = URI("#{BASE_URL}/health")
  response = Net::HTTP.get_response(uri)
  if response.code != '200'
    puts "❌ Server not responding correctly at #{BASE_URL}"
    puts "Please start the Rails server first: rails server"
    exit 1
  end
rescue => e
  puts "❌ Cannot connect to server at #{BASE_URL}"
  puts "Please start the Rails server first: rails server"
  puts "Error: #{e.message}"
  exit 1
end

puts "✅ Server is running"

# Create test user
puts "\n1. Creating test user..."
token = create_test_user
if token.nil?
  puts "❌ Failed to create test user"
  exit 1
end
puts "✅ Test user created successfully"

# Test file uploads
puts "\n2. Testing file uploads..."
results = {}

test_files.each do |filename, content|
  print "  Uploading #{filename}... "

  result = upload_file(token, filename, content)
  results[filename] = result

  if result[:code] == '201'
    puts "✅ SUCCESS"
  else
    puts "❌ FAILED (#{result[:code]})"
    puts "    Error: #{result[:body]['message'] rescue result[:body]}"
  end
end

# Summary
puts "\n" + "=" * 50
puts "UPLOAD TEST SUMMARY"
puts "=" * 50

success_count = 0
results.each do |filename, result|
  status = result[:code] == '201' ? '✅ PASS' : '❌ FAIL'
  puts "#{filename}: #{status}"
  success_count += 1 if result[:code] == '201'
end

puts "\nResults: #{success_count}/#{test_files.count} files uploaded successfully"

if success_count == test_files.count
  puts "🎉 All tests passed! Text and markdown file uploads are working correctly."
else
  puts "⚠️  Some uploads failed. Check the server logs and ALLOWED_CONTENT_TYPES configuration."

  # Show failed uploads details
  puts "\nFailed uploads details:"
  results.each do |filename, result|
    if result[:code] != '201'
      puts "#{filename}:"
      puts "  Status: #{result[:code]}"
      puts "  Error: #{result[:body]['message'] rescue result[:body]}"
      if result[:body].is_a?(Hash)
        puts "  Detected type: #{result[:body]['detected_type']}" if result[:body]['detected_type']
        puts "  Allowed types: #{result[:body]['allowed_types']}" if result[:body]['allowed_types']
      end
    end
  end
end
