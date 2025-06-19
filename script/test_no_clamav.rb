#!/usr/bin/env ruby

# Test script to verify file upload behavior when ClamAV is not available
# Run with: ruby script/test_no_clamav.rb

require 'net/http'
require 'json'
require 'tempfile'
require 'uri'

BASE_URL = 'http://localhost:3000'

class NoClamAVTest
  def initialize
    @token = nil
  end

  def run
    puts "🚫 No ClamAV Upload Test"
    puts "=" * 40

    check_server
    check_clamav_status
    create_user
    test_upload_without_clamav
    test_with_require_env_var
  end

  private

  def check_server
    puts "\n1. Checking server..."
    result = `curl -s #{BASE_URL}/health`
    if $?.success? && result.include?('ok')
      puts "✅ Server is running"
    else
      puts "❌ Server not responding"
      exit 1
    end
  end

  def check_clamav_status
    puts "\n2. Checking ClamAV status..."

    # Check if ClamAV container is running
    container_status = `docker ps --filter "name=clamav" --format "table {{.Names}}\t{{.Status}}"`.strip
    if container_status.include?("Up")
      puts "⚠️  ClamAV container is still running!"
      puts "Please stop it first: docker-compose stop clamav"
      exit 1
    else
      puts "✅ ClamAV container is stopped"
    end

    # Test Rails connection to ClamAV
    result = `cd #{File.dirname(__FILE__)}/../ && bundle exec rails runner "puts FileProcessing::VirusScanner.instance.service_available?" 2>/dev/null`.strip
    if result == "false"
      puts "✅ Rails confirms ClamAV is unavailable"
    else
      puts "❌ Rails still thinks ClamAV is available: #{result}"
      exit 1
    end

    # Check environment variables
    env_result = `cd #{File.dirname(__FILE__)}/../ && bundle exec rails runner "
      puts 'Environment: ' + Rails.env
      puts 'REQUIRE_VIRUS_SCAN: ' + ENV['REQUIRE_VIRUS_SCAN'].to_s
      puts 'SKIP_VIRUS_SCAN: ' + ENV['SKIP_VIRUS_SCAN'].to_s
    " 2>/dev/null`.strip

    puts "📝 Current configuration:"
    puts "   #{env_result}"
  end

  def create_user
    puts "\n3. Creating test user..."

    response = `curl -s -X POST #{BASE_URL}/auth/register \
      -H "Content-Type: application/json" \
      -d '{"name":"No ClamAV Test User","email":"noclamav#{Time.now.to_i}@example.com","password":"password123"}'`

    if $?.success?
      begin
        data = JSON.parse(response)
        @token = data['token']
        puts "✅ User created, got token"
      rescue
        puts "❌ Failed to parse response: #{response}"
        exit 1
      end
    else
      puts "❌ Failed to create user"
      exit 1
    end
  end

  def test_upload_without_clamav
    puts "\n4. Testing file upload without ClamAV (development mode)..."

    Tempfile.create(['no_clamav_test', '.txt']) do |file|
      file.write("This is a test file uploaded without ClamAV running.\nShould work in development mode.")
      file.flush

      response = `curl -s -X POST #{BASE_URL}/upload \
        -H "Authorization: Bearer #{@token}" \
        -F "file=@#{file.path}"`

      if $?.success?
        begin
          data = JSON.parse(response)

          if data['file'] && data['file']['virus_scan']
            scan_result = data['file']['virus_scan']
            puts "✅ File uploaded successfully in development mode"
            puts "   Scan status: #{scan_result['status']}"
            puts "   Safe: #{scan_result['safe']}"
            puts "   Warning: #{scan_result['warning']}" if scan_result['warning']
            puts "   📝 This demonstrates that uploads work without ClamAV in development"
          elsif data['message'] && data['message'].include?('unavailable')
            puts "❌ Upload was blocked due to virus scanning unavailable"
            puts "   Message: #{data['message']}"
            puts "   📝 This would happen if REQUIRE_VIRUS_SCAN=true"
          else
            puts "❌ Unexpected response: #{data}"
          end
        rescue => e
          puts "❌ Failed to parse response: #{e.message}"
          puts "Response: #{response}"
        end
      else
        puts "❌ Upload request failed"
      end
    end
  end

  def test_with_require_env_var
    puts "\n5. Testing with REQUIRE_VIRUS_SCAN=true..."

    Tempfile.create(['require_scan_test', '.txt']) do |file|
      file.write("Test file with virus scan required")
      file.flush

      response = `REQUIRE_VIRUS_SCAN=true curl -s -X POST #{BASE_URL}/upload \
        -H "Authorization: Bearer #{@token}" \
        -F "file=@#{file.path}"`

      if $?.success?
        begin
          data = JSON.parse(response)

          if data['message'] && data['message'].include?('unavailable')
            puts "✅ Upload correctly blocked when REQUIRE_VIRUS_SCAN=true"
            puts "   Message: #{data['message']}"
            puts "   📝 This is the expected production behavior"
          elsif data['file']
            puts "⚠️  Upload succeeded even with REQUIRE_VIRUS_SCAN=true"
            puts "   This might indicate the env var isn't being read properly"
          else
            puts "❌ Unexpected response: #{data}"
          end
        rescue => e
          puts "❌ Failed to parse response: #{e.message}"
          puts "Response: #{response}"
        end
      else
        puts "❌ Upload request failed"
      end
    end
  end
end

def show_usage_examples
  puts "\n" + "=" * 60
  puts "📚 USAGE EXAMPLES"
  puts "=" * 60

  puts "\n🔧 Development Mode (Default):"
  puts "# ClamAV not required - uploads work without virus scanning"
  puts "bin/rails server"
  puts "# File uploads will succeed with warning about virus scanning unavailable"

  puts "\n🛡️ Production Mode:"
  puts "# ClamAV required - uploads fail without virus scanning"
  puts "REQUIRE_VIRUS_SCAN=true bin/rails server"
  puts "# File uploads will be rejected until ClamAV is available"

  puts "\n🚀 Skip Virus Scanning (Development):"
  puts "# Completely skip virus scanning for faster development"
  puts "SKIP_VIRUS_SCAN=true bin/rails server"
  puts "# File uploads skip virus scanning entirely"

  puts "\n🐳 Start ClamAV:"
  puts "docker-compose up -d clamav"
  puts "# Wait for container to be healthy, then uploads work with virus scanning"
end

# Run if called directly
if __FILE__ == $0
  tester = NoClamAVTest.new
  tester.run
  show_usage_examples
end
