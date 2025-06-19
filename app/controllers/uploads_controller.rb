class UploadsController < ApplicationController
  include Authenticable

  # POST /upload
  def create
    file = params[:file]

    # Validate file presence
    unless file.present?
      return render json: { message: "No file provided" }, status: :unprocessable_entity
    end

    # Validate file size
    if file.size > 2.megabytes
      return render json: { message: Message.file_too_large }, status: :unprocessable_entity
    end

    # Detect content type
    content_type = Marcel::MimeType.for(file.tempfile)

    # Validate content type
    unless UserFile::ALLOWED_CONTENT_TYPES.include?(content_type)
      return render json: {
        message: Message.invalid_file_type,
        allowed_types: UserFile::ALLOWED_CONTENT_TYPES
      }, status: :unprocessable_entity
    end

    # Perform virus scan
    virus_scan_result = perform_virus_scan(file)
    unless virus_scan_result[:safe]
      return render json: {
        message: "File upload rejected: #{virus_scan_result[:error] || virus_scan_result[:threat] || 'Security check failed'}",
        scan_result: virus_scan_result
      }, status: :unprocessable_entity
    end

    # Create user file record
    @user_file = current_user.user_files.build(
      filename: file.original_filename,
      content_type: content_type,
      file_size: file.size,
      uploaded_at: Time.current
    )

    if @user_file.save
      # Attach the file using Active Storage
      @user_file.file.attach(
        io: file.tempfile,
        filename: file.original_filename,
        content_type: content_type
      )

      render json: {
        message: Message.file_uploaded,
        file: {
          id: @user_file.id,
          filename: @user_file.filename,
          content_type: @user_file.content_type,
          file_size: @user_file.file_size,
          human_readable_size: @user_file.human_readable_size,
          uploaded_at: @user_file.uploaded_at,
          is_image: @user_file.image?,
          is_text: @user_file.text?,
          virus_scan: virus_scan_result
        }
      }, status: :created
    else
      render json: {
        message: Message.file_not_uploaded,
        errors: @user_file.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "File upload error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      message: "An error occurred during file upload",
      error: e.message
    }, status: :internal_server_error
  end

  private

  def perform_virus_scan(file)
    # Skip virus scanning in test environment for faster tests
    if Rails.env.test? && ENV['SKIP_VIRUS_SCAN'] == 'true'
      return {
        status: FileProcessing::VirusScanner::SCAN_RESULT_CLEAN,
        safe: true,
        scanned_at: Time.current,
        skipped: true,
        reason: 'Test environment'
      }
    end

    scanner = FileProcessing::VirusScanner.instance

    # Check if virus scanning service is available
    unless scanner.service_available?
      Rails.logger.warn("Virus scanning service unavailable")

      # In development, we might want to allow uploads even if ClamAV isn't running
      if Rails.env.development? && ENV['REQUIRE_VIRUS_SCAN'] != 'true'
        return {
          status: FileProcessing::VirusScanner::SCAN_RESULT_CLEAN,
          safe: true,
          scanned_at: Time.current,
          warning: 'Virus scanning unavailable - allowed in development'
        }
      else
        return {
          status: FileProcessing::VirusScanner::SCAN_RESULT_ERROR,
          safe: false,
          error: 'Virus scanning service unavailable',
          scanned_at: Time.current
        }
      end
    end

    # Perform the actual virus scan
    scanner.scan_file(file)
  rescue => e
    Rails.logger.error("Virus scan error: #{e.message}")
    {
      status: FileProcessing::VirusScanner::SCAN_RESULT_ERROR,
      safe: false,
      error: e.message,
      scanned_at: Time.current
    }
  end

  def file_params
    params.permit(:file)
  end
end
