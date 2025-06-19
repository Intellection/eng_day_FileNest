require 'rails_helper'

RSpec.describe FilesController, type: :controller do
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com', password: 'password123') }
  let(:user_file) { UserFile.create!(user: user, filename: 'test.txt', content_type: 'text/plain', file_size: 1024, uploaded_at: Time.current) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authorize_request)
  end

  describe 'GET #index' do
    it 'returns a list of user files' do
      user_file
      get :index
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['files']).to be_an(Array)
    end
  end

  describe 'GET #show' do
    it 'returns file details' do
      get :show, params: { id: user_file.id }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['file']['filename']).to eq('test.txt')
    end
  end

  describe 'PATCH #update' do
    it 'updates filename successfully' do
      patch :update, params: { id: user_file.id, file: { filename: 'updated.txt' } }
      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['file']['filename']).to eq('updated.txt')
    end
  end
end
