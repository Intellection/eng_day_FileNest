Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # SnapVault health check
  get "health", to: "health#show"

  # SnapVault Authentication routes
  post "auth/login", to: "auth#login"
  post "auth/register", to: "auth#register"

  # SnapVault File operations
  post "upload", to: "uploads#create"
  get "files", to: "files#index"
  get "files/:id", to: "files#show"
  get "files/:id/download", to: "files#download"
  delete "files/:id", to: "files#destroy"

  # Defines the root path route ("/")
  root "home#index"
end
