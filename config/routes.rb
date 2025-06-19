Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # SnapVault health check
  get "health", to: "health#show", as: :health

  # SnapVault Authentication routes
  post "auth/login", to: "auth#login", as: :auth_login
  post "auth/register", to: "auth#register", as: :auth_register

  # SnapVault File operations
  post "upload", to: "uploads#create", as: :upload
  get "files", to: "files#index", as: :files
  get "files/:id", to: "files#show", as: :file
  get "files/:id/download", to: "files#download", as: :download_file
  delete "files/:id", to: "files#destroy"

  # Defines the root path route ("/")
  root "home#index"
end
