require 'rails_helper'

RSpec.describe UserFile, type: :model do
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com', password: 'password123') }

  describe 'validations' do
    it 'is valid with valid attributes' do
      user_file = UserFile.new(
        user: user,
        filename: 'test.txt',
        content_type: 'text/plain',
        file_size: 1024,
        uploaded_at: Time.current
      )
      expect(user_file).to be_valid
    end

    it 'is invalid without a filename' do
      user_file = UserFile.new(
        user: user,
        content_type: 'text/plain',
        file_size: 1024,
        uploaded_at: Time.current
      )
      expect(user_file).not_to be_valid
    end

    it 'is invalid with filename starting with dot' do
      user_file = UserFile.new(
        user: user,
        filename: '.hidden.txt',
        content_type: 'text/plain',
        file_size: 1024,
        uploaded_at: Time.current
      )
      expect(user_file).not_to be_valid
    end
  end
end
