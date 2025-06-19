class HealthController < ApplicationController
  skip_before_action :authorize_request, only: [ :show ]

  # GET /health
  def show
    render json: {
      status: "ok",
      timestamp: Time.current.iso8601,
      version: "1.0.0",
      service: "FileNest",
      uptime: uptime_in_seconds,
      database: database_status,
      storage: storage_status
    }, status: :ok
  rescue => e
    render json: {
      status: "error",
      timestamp: Time.current.iso8601,
      service: "FileNest",
      error: e.message
    }, status: :internal_server_error
  end

  private

  def uptime_in_seconds
    Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i
  end

  def database_status
    ActiveRecord::Base.connection.active? ? "connected" : "disconnected"
  rescue
    "error"
  end

  def storage_status
    # Check if Active Storage is working
    ActiveStorage::Blob.count >= 0 ? "available" : "unavailable"
  rescue
    "error"
  end
end
