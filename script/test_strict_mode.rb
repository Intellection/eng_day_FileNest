#!/usr/bin/env ruby

# Test script to verify upload behavior in strict virus scanning mode
# Run with: REQUIRE_VIRUS_SCAN=true ruby script/test_strict_mode.rb

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
    name: "Strict Mode Test User",
    email: "strict#{Time.now.to_i}@example.com",
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

def test_upload_with_strict_mode(token)
  puts "Testing file upload in strict virus scanning mode..."

  Tempfile.create(['strict_test', '.txt']) do |file|
    file.write("Test file for strict virus scanning mode")
    file.flush

    response = `curl -s -X POST #{BASE_URL}/upload \
      -H "Authorization: Bearer #{token}" \
      -F "file=@#{file.path}"`

    begin
      data = JSON.parse(response)

      if data['message'] && (data['message'].include?('virus scanning service unavailable') || data['message'].include?('Virus scanning service unavailable'))
        puts "✅ PASS: Upload correctly blocked in strict mode"
        puts "   Message: #{data['message']}"
        puts "   📝 This is expected when REQUIRE_VIRUS_SCAN=true and ClamAV is unavailable"
        return true
      elsif data['file']
        puts "❌ FAIL: Upload succeeded when it should have been blocked"
        puts "   Response: #{data}"
        return false
      else
        puts "❌ UNEXPECTED: #{data}"
        return false
      end
    rescue => e
      puts "❌ Failed to parse response: #{e.message}"
      puts "Response: #{response}"
      return false
    end
  end
end

# Main execution
puts "🛡️ Strict Virus Scanning Mode Test"
puts "=" * 45

# Check if server is running
begin
  uri = URI("#{BASE_URL}/health")
  response = Net::HTTP.get_response(uri)
  if response.code != '200'
    puts "❌ Server not responding at #{BASE_URL}"
    exit 1
  end
rescue => e
  puts "❌ Cannot connect to server: #{e.message}"
  exit 1
end

puts "✅ Server is running"

# Check that ClamAV is not running
clamav_status = `docker ps --filter "name=clamav" --format "{{.Status}}"`.strip
if clamav_status.include?("Up")
  puts "❌ ClamAV is still running. Stop it first: docker-compose stop clamav"
  exit 1
end

puts "✅ ClamAV is stopped (as expected for this test)"

# Create user and test
token = create_test_user
if token.nil?
  puts "❌ Failed to create test user"
  exit 1
end

puts "✅ Test user created"

# Test upload
if test_upload_with_strict_mode(token)
  puts "\n🎉 Strict mode test PASSED!"
  puts "File uploads are properly blocked when:"
  puts "- REQUIRE_VIRUS_SCAN=true"
  puts "- ClamAV is unavailable"
  puts "\nThis ensures production security!"
else
  puts "\n❌ Strict mode test FAILED!"
  puts "File uploads should be blocked when virus scanning is required but unavailable."
end

puts "\n" + "=" * 45
puts "To test different modes:"
puts "1. Normal development: bin/rails server"
puts "2. Strict mode: REQUIRE_VIRUS_SCAN=true bin/rails server"
puts "3. Skip scanning: SKIP_VIRUS_SCAN=true bin/rails server"
puts "4. With ClamAV: docker-compose up -d clamav && bin/rails server"
