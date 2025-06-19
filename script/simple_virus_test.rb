#!/usr/bin/env ruby

# Simple virus scanning test using curl
# Run with: ruby script/simple_virus_test.rb

require 'json'
require 'tempfile'

BASE_URL = 'http://localhost:3000'
EICAR_TEST_STRING = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

class SimpleVirusTest
  def initialize
    @token = nil
  end

  def run
    puts "🔬 Simple Virus Scanning Test"
    puts "=" * 40

    check_server
    create_user
    test_clean_file
    test_virus_file
    test_direct_scanner
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

  def create_user
    puts "\n2. Creating test user..."

    response = `curl -s -X POST #{BASE_URL}/auth/register \
      -H "Content-Type: application/json" \
      -d '{"name":"Test User","email":"test#{Time.now.to_i}@example.com","password":"password123"}'`

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

  def test_clean_file
    puts "\n3. Testing clean file upload..."

    Tempfile.create(['clean', '.txt']) do |file|
      file.write("This is a clean test file.\nNo viruses here!")
      file.flush

      response = `curl -s -X POST #{BASE_URL}/upload \
        -H "Authorization: Bearer #{@token}" \
        -F "file=@#{file.path}"`

      if $?.success?
        begin
          data = JSON.parse(response)
          if data['file'] && data['file']['virus_scan']
            scan_result = data['file']['virus_scan']
            if scan_result['safe']
              puts "✅ Clean file uploaded successfully"
              puts "   Scan status: #{scan_result['status']}"
              puts "   Safe: #{scan_result['safe']}"
            else
              puts "❌ Clean file marked as unsafe: #{scan_result}"
            end
          else
            puts "❌ Upload failed: #{data['message']}"
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

  def test_virus_file
    puts "\n4. Testing virus file upload (EICAR)..."

    Tempfile.create(['eicar', '.txt']) do |file|
      file.write(EICAR_TEST_STRING)
      file.flush

      response = `curl -s -X POST #{BASE_URL}/upload \
        -H "Authorization: Bearer #{@token}" \
        -F "file=@#{file.path}"`

      if $?.success?
        begin
          data = JSON.parse(response)
          if data['message'] && data['message'].include?('rejected')
            puts "✅ Virus file correctly rejected"
            puts "   Message: #{data['message']}"
            if data['scan_result'] && data['scan_result']['threat']
              puts "   Threat detected: #{data['scan_result']['threat']}"
            end
          else
            puts "🚨 CRITICAL: Virus file was NOT rejected!"
            puts "Response: #{data}"
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

  def test_direct_scanner
    puts "\n5. Testing virus scanner directly..."

    # Test clean file
    puts "   Testing clean file scan..."
    Tempfile.create(['direct_clean', '.txt']) do |file|
      file.write("Direct test - clean content")
      file.flush

      result = `cd #{File.dirname(__FILE__)}/../ && bundle exec rails runner "
        scanner = FileProcessing::VirusScanner.instance
        result = scanner.scan_file('#{file.path}')
        puts result.to_json
      " 2>/dev/null`.strip

      begin
        data = JSON.parse(result)
        if data['safe']
          puts "   ✅ Direct clean scan: PASS"
        else
          puts "   ❌ Direct clean scan: FAIL - #{data}"
        end
      rescue
        puts "   ❌ Direct scan failed: #{result}"
      end
    end

    # Test virus file
    puts "   Testing virus file scan..."
    Tempfile.create(['direct_virus', '.txt']) do |file|
      file.write(EICAR_TEST_STRING)
      file.flush

      result = `cd #{File.dirname(__FILE__)}/../ && bundle exec rails runner "
        scanner = FileProcessing::VirusScanner.instance
        result = scanner.scan_file('#{file.path}')
        puts result.to_json
      " 2>/dev/null`.strip

      begin
        data = JSON.parse(result)
        if !data['safe'] && data['threat']
          puts "   ✅ Direct virus scan: PASS - detected #{data['threat']}"
        else
          puts "   🚨 Direct virus scan: FAIL - virus not detected!"
          puts "   Result: #{data}"
        end
      rescue
        puts "   ❌ Direct scan failed: #{result}"
      end
    end
  end
end

# Run if called directly
if __FILE__ == $0
  tester = SimpleVirusTest.new
  tester.run
end
