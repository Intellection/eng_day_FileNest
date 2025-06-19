class FilesController < ApplicationController
  include Authenticable

  before_action :set_user_file, only: [ :show, :download, :destroy ]

  # GET /files
  def index
    @user_files = current_user.user_files.recent.includes(file_attachment: :blob)

    files_data = @user_files.map do |user_file|
      {
        id: user_file.id,
        filename: user_file.filename,
        content_type: user_file.content_type,
        file_size: user_file.file_size,
        human_readable_size: user_file.human_readable_size,
        uploaded_at: user_file.uploaded_at,
        is_image: user_file.image?,
        is_text: user_file.text?,
        file_extension: user_file.file_extension,
        download_url: user_file.file.attached? ? rails_blob_path(user_file.file, disposition: "attachment") : nil
      }
    end

    render json: {
      files: files_data,
      total_count: @user_files.count,
      total_size: @user_files.sum(:file_size),
      human_readable_total_size: human_readable_size(@user_files.sum(:file_size))
    }, status: :ok
  end

  # GET /files/:id
  def show
    authorize_file_access!(@user_file)

    render json: {
      file: {
        id: @user_file.id,
        filename: @user_file.filename,
        content_type: @user_file.content_type,
        file_size: @user_file.file_size,
        human_readable_size: @user_file.human_readable_size,
        uploaded_at: @user_file.uploaded_at,
        is_image: @user_file.image?,
        is_text: @user_file.text?,
        file_extension: @user_file.file_extension,
        download_url: @user_file.file.attached? ? rails_blob_path(@user_file.file, disposition: "attachment") : nil,
        preview_url: @user_file.image? && @user_file.file.attached? ? rails_blob_path(@user_file.file) : nil
      }
    }, status: :ok
  end

  # GET /files/:id/download
  def download
    authorize_file_access!(@user_file)

    if @user_file.file.attached?
      redirect_to rails_blob_path(@user_file.file, disposition: "attachment")
    else
      render json: { message: "File not found or corrupted" }, status: :not_found
    end
  end

  # DELETE /files/:id
  def destroy
    authorize_file_access!(@user_file)

    if @user_file.destroy
      render json: { message: "File deleted successfully" }, status: :ok
    else
      render json: {
        message: "Failed to delete file",
        errors: @user_file.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def set_user_file
    @user_file = UserFile.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { message: Message.file_not_found }, status: :not_found
  end

  def human_readable_size(size_in_bytes)
    return "0 B" if size_in_bytes.zero?

    units = [ "B", "KB", "MB", "GB" ]
    size = size_in_bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end
end
