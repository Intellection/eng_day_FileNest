class UserFile < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  validates :filename, presence: true, uniqueness: { scope: :user_id }, length: { maximum: 255 }
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

  private

  def set_uploaded_at
    self.uploaded_at = Time.current
  end
end
