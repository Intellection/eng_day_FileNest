class Message
  def self.not_found(record = "record")
    "Sorry, #{record} not found."
  end

  def self.invalid_credentials
    "Invalid credentials"
  end

  def self.invalid_token
    "Invalid token"
  end

  def self.missing_token
    "Missing token"
  end

  def self.unauthorized
    "Unauthorized request"
  end

  def self.account_created
    "Account created successfully"
  end

  def self.account_not_created
    "Account could not be created"
  end

  def self.expired_token
    "Sorry, your token has expired. Please login to continue."
  end

  def self.file_uploaded
    "File uploaded successfully"
  end

  def self.file_not_uploaded
    "File could not be uploaded"
  end

  def self.file_too_large
    "File size exceeds 2MB limit"
  end

  def self.invalid_file_type
    "File type not supported"
  end

  def self.file_not_found
    "File not found"
  end

  def self.access_denied
    "Access denied. You can only access your own files."
  end
end
