require 'rails_helper'

RSpec.describe AuthController, type: :controller do
  describe 'POST #register' do
    it 'creates a new user with valid params' do
      expect {
        post :register, params: { name: 'John Doe', email: 'john@example.com', password: 'password123' }
      }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'returns error with invalid email' do
      post :register, params: { name: 'John Doe', email: 'invalid-email', password: 'password123' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns error with missing password' do
      post :register, params: { name: 'John Doe', email: 'john@example.com' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
