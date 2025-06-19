class User < ApplicationRecord
  has_secure_password

  has_many :user_files, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true, length: { maximum: 100 }
  validates :email, length: { maximum: 255 }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

  before_validation :strip_whitespace
  before_save :downcase_email

  def to_token_payload
    {
      sub: id,
      email: email,
      name: name
    }
  end

  def file_stats
    total_files = user_files.count
    total_size = user_files.sum(:file_size)

    {
      total_files: total_files,
      total_size: total_size,
      human_readable_size: human_readable_size(total_size)
    }
  end

  private

  def downcase_email
    self.email = email.downcase if email.present?
  end

  def strip_whitespace
    self.name = name.strip if name.present?
    self.email = email.strip if email.present?
  end

  def human_readable_size(size_in_bytes)
    return "0 B" if size_in_bytes.zero?

    units = ["B", "KB", "MB", "GB"]
    size = size_in_bytes.to_f
    unit_index = 0

    while size >= 1024 && unit_index < units.length - 1
      size /= 1024
      unit_index += 1
    end

    "#{size.round(2)} #{units[unit_index]}"
  end
end
