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
    detected_content_type = Marcel::MimeType.for(file.tempfile)
    Rails.logger.info "Marcel detected MIME type: #{detected_content_type} for file: #{file.original_filename}"

    # Fallback MIME type detection based on file extension
    if detected_content_type.nil? || detected_content_type == "application/octet-stream"
      extension = File.extname(file.original_filename).downcase
      content_type = case extension
      when '.txt'
        'text/plain'
      when '.md', '.markdown'
        'text/markdown'
      when '.csv'
        'text/csv'
      when '.jpg', '.jpeg'
        'image/jpeg'
      when '.png'
        'image/png'
      when '.gif'
        'image/gif'
      when '.svg'
        'image/svg+xml'
      else
        detected_content_type
      end
      Rails.logger.info "Using fallback MIME type: #{content_type} for extension: #{extension}"
    else
      content_type = detected_content_type
    end

    Rails.logger.info "Final MIME type used: #{content_type}"

    # Validate content type and file extension
    unless UserFile::ALLOWED_CONTENT_TYPES.include?(content_type)
      return render json: {
        message: Message.invalid_file_type,
        allowed_types: UserFile::ALLOWED_CONTENT_TYPES.reject { |t| t == 'application/octet-stream' },
        detected_type: content_type
      }, status: :unprocessable_entity
    end

    # Additional validation for octet-stream files
    if content_type == "application/octet-stream"
      extension = File.extname(file.original_filename).downcase
      unless UserFile::ALLOWED_FILE_EXTENSIONS.include?(extension)
        return render json: {
          message: "File extension not supported",
          allowed_extensions: UserFile::ALLOWED_FILE_EXTENSIONS,
          detected_extension: extension
        }, status: :unprocessable_entity
      end
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
          is_text: @user_file.text?
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

  def file_params
    params.permit(:file)
  end
end
