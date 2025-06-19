require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "should return health status" do
    get health_path

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert_equal "ok", json_response["status"]
    assert json_response["timestamp"].present?
    assert_equal "1.0.0", json_response["version"]
    assert_equal "FileNest", json_response["service"]
    assert json_response["uptime"].present?
    assert json_response.key?("database")
    assert json_response.key?("storage")
  end

  test "should return valid timestamp format" do
    get health_path

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should be a valid ISO 8601 timestamp
    timestamp = json_response["timestamp"]
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/, timestamp

    # Should parse as valid time
    assert_nothing_raised do
      Time.parse(timestamp)
    end
  end

  test "should return numeric uptime" do
    get health_path

    assert_response :ok
    json_response = JSON.parse(response.body)

    uptime = json_response["uptime"]
    assert uptime.is_a?(Numeric)
    assert uptime >= 0
  end

  test "should include database status" do
    get health_path

    assert_response :ok
    json_response = JSON.parse(response.body)

    database_status = json_response["database"]
    assert_includes %w[connected disconnected], database_status
  end

  test "should include storage status" do
    get health_path

    assert_response :ok
    json_response = JSON.parse(response.body)

    storage_status = json_response["storage"]
    assert_includes %w[available unavailable], storage_status
  end

  test "should respond quickly" do
    start_time = Time.current

    get health_path

    end_time = Time.current
    response_time = end_time - start_time

    assert_response :ok
    # Health check should respond within 1 second
    assert response_time < 1.0, "Health check took too long: #{response_time}s"
  end

  test "should not require authentication" do
    # Health endpoint should be public
    get health_path

    assert_response :ok
    # Should not return unauthorized
    assert_not_equal 401, response.status
  end

  test "should handle concurrent requests" do
    threads = []
    results = []

    # Make 5 concurrent requests
    5.times do
      threads << Thread.new do
        get health_path
        results << response.status
      end
    end

    threads.each(&:join)

    # All requests should succeed
    assert results.all? { |status| status == 200 }
  end

  test "should return consistent response structure" do
    # Make multiple requests to ensure consistency
    responses = []

    3.times do
      get health_path
      responses << JSON.parse(response.body)
    end

    # All responses should have the same keys
    first_keys = responses.first.keys.sort
    responses.each do |response|
      assert_equal first_keys, response.keys.sort
    end
  end
end
