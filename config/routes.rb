Rails.application.routes.draw do
  # Root - главная страница лендинга DeliveryTracker
  root "landing#index"

  # Mission Control Jobs - production monitoring
  mount MissionControl::Jobs::Engine => "/jobs"

  # Authentication routes - Telegram (MVP)
  get "login" => "sessions#new"
  get "signup" => "users#new"
  delete "logout" => "sessions#destroy"

  # Telegram authentication
  post "auth/telegram/webhook" => "telegram_auth#webhook"
  get "auth/telegram/:token" => "telegram_auth#auth_with_token", as: :telegram_token_auth
  post "auth/telegram/callback" => "telegram_auth#create", as: :telegram_callback

  # TODO: RESTORE EMAIL AUTHENTICATION ROUTES AFTER MVP
  # Email-based authentication temporarily disabled for MVP
  # Uncomment these routes to re-enable email/password authentication

  # resource :session, only: [ :new, :create, :destroy ]
  # post "login" => "sessions#create"

  # # User registration
  # resources :users, only: [ :new, :create ]
  # post "signup" => "users#create"

  # # Email confirmation
  # get "email_confirmation" => "email_confirmations#show"
  # resources :email_confirmations, only: [ :new, :create ]
  # get "resend_confirmation" => "email_confirmations#new"
  # post "resend_confirmation" => "email_confirmations#create"

  # # Password reset
  # resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]
  # get "forgot_password" => "passwords#new"
  # post "forgot_password" => "passwords#create"
  # get "reset_password" => "passwords#edit"
  # patch "reset_password" => "passwords#update"

  # Protected routes
  get "dashboard" => "dashboards#show"
  get "dashboard/status_data" => "dashboards#status_data"
  get "dashboard/timeline_data" => "dashboards#timeline_data"
  get "onboarding" => "dashboards#onboarding"

  # Restaurant management
  resources :restaurants, only: [ :create, :show, :update, :destroy ] do
    collection do
      post :extract_data
      post :extract_gojek_data
      post :extract_grab_data
    end
    member do
      patch :toggle_active
      get :analytics
      get :analytics_data
    end
  end

  get "landing/index"
  get "landing/test"
  get "landing/test_cuisines"
  get "index" => "landing#index"  # Для aidelivery.tech/index

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
