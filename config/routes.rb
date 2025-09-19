Rails.application.routes.draw do
  # Root - главная страница лендинга DeliveryTracker
  root "landing#index"

  # Authentication routes
  resource :session, only: [ :new, :create, :destroy ]
  get "login" => "sessions#new"
  post "login" => "sessions#create"
  delete "logout" => "sessions#destroy"

  # User registration
  resources :users, only: [ :new, :create ]
  get "signup" => "users#new"
  post "signup" => "users#create"

  # Email confirmation
  get "email_confirmation" => "email_confirmations#show"
  resources :email_confirmations, only: [ :new, :create ]
  get "resend_confirmation" => "email_confirmations#new"
  post "resend_confirmation" => "email_confirmations#create"

  # Password reset
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]
  get "forgot_password" => "passwords#new"
  post "forgot_password" => "passwords#create"
  get "reset_password" => "passwords#edit"
  patch "reset_password" => "passwords#update"

  # Protected routes
  get "dashboard" => "dev#dashboard"
  get "onboarding" => "dev#onboarding"

  # Restaurant management
  resources :restaurants, only: [ :create ] do
    collection do
      post :extract_data
    end
  end

  get "landing/index"
  get "landing/test"
  get "landing/test_cuisines"
  get "index" => "landing#index"  # Для aidelivery.tech/index

  # Dev routes для новой версии с v0.dev
  get "dev/test" => "dev#test"       # aidelivery.tech/dev/test
  get "dev/dashboard" => "dev#dashboard"
  get "dev/onboarding" => "dev#onboarding"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
