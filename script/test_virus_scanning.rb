#!/usr/bin/env ruby

# Comprehensive virus scanning test script
# Tests the ClamAV integration and virus scanning workflow
# Run with: ruby script/test_virus_scanning.rb

require 'net/http'
require 'json'
require 'tempfile'
require 'uri'

BASE_URL = 'http://localhost:3000'

# EICAR test virus string - standard test pattern for antivirus software
# This is NOT a real virus, just a test pattern that all antivirus software detects
EICAR_TEST_STRING = 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*'

class VirusScanningTester
  def initialize
    @results = {}
    @token = nil
  end

  def run
    puts "🦠 Virus Scanning Test Suite"
    puts "=" * 60

    check_server_health
    check_clamav_status
    create_test_user
    run_virus_scanning_tests
    display_summary
  end

  private

  def check_server_health
    puts "\n1. Checking server health..."
    begin
      uri = URI("#{BASE_URL}/health")
      response = Net::HTTP.get_response(uri)
      if response.code == '200'
        puts "✅ Rails server is running"
      else
        puts "❌ Server health check failed (#{response.code})"
        exit 1
      end
    rescue => e
      puts "❌ Cannot connect to server at #{BASE_URL}"
      puts "Please start the Rails server: bundle exec rails server"
      exit 1
    end
  end

  def check_clamav_status
    puts "\n2. Checking ClamAV status..."

    # Check if ClamAV container is running
    puts "  Checking Docker container..."
    container_status = `docker ps --filter "name=clamav" --format "table {{.Names}}\t{{.Status}}"`.strip
    if container_status.include?("Up") && container_status.include?("healthy")
      puts "✅ ClamAV Docker container is running and healthy"
    else
      puts "❌ ClamAV container not running. Start with: docker-compose up -d clamav"
      puts "Container status: #{container_status}"
      exit 1
    end

    # Test Rails connection to ClamAV
    puts "  Testing Rails -> ClamAV connection..."
    begin
      output = `cd #{File.dirname(__FILE__)}/../ && bundle exec rails runner "puts FileProcessing::VirusScanner.instance.service_available?" 2>/dev/null`.strip
      if output == "true"
        puts "✅ Rails can connect to ClamAV"

        # Get version info
        version = `cd #{File.dirname(__FILE__)}/../ && bundle exec rails runner "puts FileProcessing::VirusScanner.instance.version_info" 2>/dev/null`.strip
        puts "📝 ClamAV Version: #{version}" unless version.empty?
      else
        puts "❌ Rails cannot connect to ClamAV"
        puts "Output: #{output}"
        exit 1
      end
    rescue => e
      puts "❌ Error testing ClamAV connection: #{e.message}"
      exit 1
    end
  end

  def create_test_user
    puts "\n3. Creating test user..."
    uri = URI("#{BASE_URL}/auth/register")
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      name: "Virus Test User",
      email: "virustest#{Time.now.to_i}@example.com",
      password: "password123"
    }.to_json

    response = http.request(request)
    if response.code == '201'
      @token = JSON.parse(response.body)['token']
      puts "✅ Test user created successfully"
    else
      puts "❌ Failed to create user: #{response.body}"
      exit 1
    end
  end

  def run_virus_scanning_tests
    puts "\n4. Running virus scanning tests..."

    test_cases = [
      {
        name: "Clean Text File",
        filename: "clean_document.txt",
        content: "This is a clean text document with no viruses.\nIt should pass the virus scan successfully.",
        expected_result: :pass,
        description: "Normal file that should pass virus scanning"
      },
      {
        name: "Clean Markdown File",
        filename: "clean_readme.md",
        content: "# Clean Markdown File\n\nThis is a **clean** markdown file with:\n\n- No viruses\n- Safe content\n- Should pass scanning\n\n```ruby\nputs 'Hello World'\n```",
        expected_result: :pass,
        description: "Markdown file that should pass virus scanning"
      },
      {
        name: "EICAR Test Virus",
        filename: "eicar_test.txt",
        content: EICAR_TEST_STRING,
        expected_result: :blocked,
        description: "Standard antivirus test file - should be detected and blocked"
      },
      {
        name: "EICAR in Markdown",
        filename: "infected_readme.md",
        content: "# Infected File\n\nThis file contains the EICAR test string:\n\n#{EICAR_TEST_STRING}\n\nIt should be blocked.",
        expected_result: :blocked,
        description: "Markdown file with EICAR test string embedded"
      },
      {
        name: "EICAR with Different Extension",
        filename: "malicious_data.csv",
        content: "name,data,virus\ntest,clean,no\neicar,#{EICAR_TEST_STRING},yes",
        expected_result: :blocked,
        description: "CSV file with EICAR test string - should be blocked regardless of extension"
      }
    ]

    test_cases.each_with_index do |test_case, index|
      puts "\n  Test #{index + 1}/#{test_cases.length}: #{test_case[:name]}"
      puts "  Description: #{test_case[:description]}"

      result = upload_test_file(test_case[:filename], test_case[:content])
      @results[test_case[:name]] = {
        expected: test_case[:expected_result],
        actual: result[:status],
        details: result
      }

      case test_case[:expected_result]
      when :pass
        if result[:status] == :success
          puts "  ✅ PASS - File uploaded successfully (virus scan clean)"
        else
          puts "  ❌ FAIL - Expected upload to succeed but it was blocked"
          puts "  Reason: #{result[:message]}"
        end
      when :blocked
        if result[:status] == :blocked
          puts "  ✅ PASS - File correctly blocked by virus scanner"
          puts "  Threat detected: #{result[:threat] || 'Unknown threat'}"
        else
          puts "  ❌ CRITICAL FAIL - Virus was NOT detected! This is a security issue!"
          puts "  File was uploaded when it should have been blocked"
        end
      end
    end
  end

  def upload_test_file(filename, content)
    uri = URI("#{BASE_URL}/upload")
    http = Net::HTTP.new(uri.host, uri.port)

    Tempfile.create([File.basename(filename, '.*'), File.extname(filename)]) do |tempfile|
      tempfile.write(content)
      tempfile.rewind

      boundary = "----VirusTestBoundary#{Time.now.to_i}"
      post_body = []
      post_body << "--#{boundary}\r\n"
      post_body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
      post_body << "Content-Type: application/octet-stream\r\n"
      post_body << "\r\n"
      post_body << tempfile.read
      post_body << "\r\n--#{boundary}--\r\n"

      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{@token}"
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
      request.body = post_body.join

      response = http.request(request)
      response_body = JSON.parse(response.body) rescue response.body

      case response.code
      when '201'
        {
          status: :success,
          message: response_body['message'],
          virus_scan: response_body.dig('file', 'virus_scan')
        }
      when '422'
        if response_body['message']&.include?('virus') || response_body['message']&.include?('Security check failed')
          {
            status: :blocked,
            message: response_body['message'],
            threat: response_body.dig('scan_result', 'threat'),
            scan_result: response_body['scan_result']
          }
        else
          {
            status: :validation_error,
            message: response_body['message']
          }
        end
      else
        {
          status: :error,
          message: "HTTP #{response.code}: #{response_body}"
        }
      end
    end
  rescue => e
    {
      status: :error,
      message: "Exception: #{e.message}"
    }
  end

  def display_summary
    puts "\n" + "=" * 60
    puts "🦠 VIRUS SCANNING TEST SUMMARY"
    puts "=" * 60

    passed = 0
    critical_failures = 0

    @results.each do |test_name, result|
      expected = result[:expected]
      actual = result[:actual]

      if (expected == :pass && actual == :success) || (expected == :blocked && actual == :blocked)
        puts "✅ #{test_name}: PASS"
        passed += 1
      elsif expected == :blocked && actual == :success
        puts "🚨 #{test_name}: CRITICAL FAILURE - VIRUS NOT DETECTED!"
        critical_failures += 1
      else
        puts "❌ #{test_name}: FAIL"
        puts "   Expected: #{expected}, Got: #{actual}"
        puts "   Details: #{result[:details][:message]}"
      end
    end

    puts "\nResults: #{passed}/#{@results.count} tests passed"

    if critical_failures > 0
      puts "\n🚨 CRITICAL SECURITY ISSUE DETECTED!"
      puts "#{critical_failures} virus(es) were NOT detected by the scanning system."
      puts "This represents a serious security vulnerability."
      puts "\nTroubleshooting steps:"
      puts "1. Verify ClamAV is running: docker-compose logs clamav"
      puts "2. Check virus definitions are up to date: docker exec snapvault_clamav freshclam"
      puts "3. Test ClamAV directly: echo '#{EICAR_TEST_STRING}' | docker exec -i snapvault_clamav clamdscan -"
      puts "4. Check Rails logs for virus scanning errors"
    elsif passed == @results.count
      puts "\n🎉 All virus scanning tests passed!"
      puts "✅ Clean files are uploaded successfully"
      puts "✅ Virus-infected files are properly blocked"
      puts "✅ Your application is protected against malware uploads"
    else
      puts "\n⚠️  Some tests failed. Check the details above."
    end

    puts "\nFor more detailed virus scanning logs, check:"
    puts "- Rails logs: tail -f log/development.log"
    puts "- ClamAV logs: docker-compose logs -f clamav"
  end
end

# Run the tests
if __FILE__ == $0
  tester = VirusScanningTester.new
  tester.run
end
