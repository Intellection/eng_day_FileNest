class User < ApplicationRecord
  has_secure_password

  has_many :user_files, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

  before_save :downcase_email

  def to_token_payload
    {
      sub: id,
      email: email,
      name: name
    }
  end

  private

  def downcase_email
    self.email = email.downcase
  end
end
