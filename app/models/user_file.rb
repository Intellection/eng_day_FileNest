class UserFile < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  validates :filename, presence: true, length: { minimum: 1, maximum: 255 }
  validate :validate_filename_format
  validates :content_type, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 2.megabytes }
  validates :uploaded_at, presence: true

  ALLOWED_CONTENT_TYPES = [
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/gif",
    "image/svg+xml",
    "text/plain",
    "text/markdown",
    "text/x-markdown",
    "application/x-markdown",
    "text/x-web-markdown",
    "text/csv",
    "application/csv",
    "application/octet-stream"
  ].freeze

  ALLOWED_FILE_EXTENSIONS = [
    ".jpg", ".jpeg", ".png", ".gif", ".svg",
    ".txt", ".md", ".markdown", ".csv"
  ].freeze

  validate :validate_file_type

  def validate_file_type
    return if content_type.blank? || filename.blank?

    unless ALLOWED_CONTENT_TYPES.include?(content_type)
      errors.add(:content_type, "is not supported. Allowed types: #{ALLOWED_CONTENT_TYPES.reject { |t| t == 'application/octet-stream' }.join(', ')}")
      return
    end

    # Additional validation for octet-stream files based on extension
    if content_type == "application/octet-stream"
      extension = File.extname(filename).downcase
      unless ALLOWED_FILE_EXTENSIONS.include?(extension)
        errors.add(:filename, "extension #{extension} is not supported. Allowed extensions: #{ALLOWED_FILE_EXTENSIONS.join(', ')}")
      end
    end
  end

  def validate_filename_format
    return if filename.blank?

    # Sanitize and validate filename
    sanitized_name = sanitize_filename(filename)

    # Check for invalid characters
    if filename != sanitized_name
      errors.add(:filename, "contains invalid characters. Only letters, numbers, spaces, hyphens, underscores, and dots are allowed.")
      return
    end

    # Check for reserved names (Windows)
    reserved_names = %w[CON PRN AUX NUL COM1 COM2 COM3 COM4 COM5 COM6 COM7 COM8 COM9 LPT1 LPT2 LPT3 LPT4 LPT5 LPT6 LPT7 LPT8 LPT9]
    base_name = File.basename(filename, File.extname(filename)).upcase
    if reserved_names.include?(base_name)
      errors.add(:filename, "uses a reserved system name")
      return
    end

    # Check if filename starts or ends with dot or space
    if filename.start_with?('.', ' ') || filename.end_with?(' ')
      errors.add(:filename, "cannot start or end with a dot or space")
      return
    end

    # Ensure file has an extension when renaming
    if File.extname(filename).blank?
      errors.add(:filename, "must include a file extension")
      return
    end

    # Validate file extension matches allowed types
    extension = File.extname(filename).downcase
    unless ALLOWED_FILE_EXTENSIONS.include?(extension)
      errors.add(:filename, "extension #{extension} is not supported. Allowed extensions: #{ALLOWED_FILE_EXTENSIONS.join(', ')}")
    end
  end

  before_validation :set_uploaded_at, on: :create

  scope :recent, -> { order(uploaded_at: :desc) }
  scope :by_type, ->(type) { where(content_type: type) }

  def image?
    content_type.start_with?("image/")
  end

  def text?
    content_type.start_with?("text/") ||
    content_type.include?("csv") ||
    content_type.include?("markdown")
  end

  def file_extension
    File.extname(filename).downcase
  end

  def human_readable_size
    return "0 B" if file_size.zero?

    units = [ "B", "KB", "MB", "GB" ]
    size = file_size.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end

  def sanitize_filename(filename)
    # Remove or replace invalid characters
    # Allow: letters, numbers, spaces, hyphens, underscores, dots
    filename.gsub(/[^\w\s\-\.]/, '').strip
  end

  def rename_to(new_filename)
    # Preserve the original extension if not provided
    if File.extname(new_filename).blank? && File.extname(self.filename).present?
      new_filename += File.extname(self.filename)
    end

    self.filename = new_filename
  end

  private

  def set_uploaded_at
    self.uploaded_at = Time.current
  end
end
