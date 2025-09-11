Rails.application.routes.draw do
  get "landing/index"
  get "index" => "landing#index"  # Для aidelivery.tech/index
  get "test" => "landing#test"
  
  # Dev routes для новой версии с v0.dev
  get "dev/test" => "dev#test"       # aidelivery.tech/dev/test
  get "dev/dashboard" => "dev#dashboard"
  get "dev/onboarding" => "dev#onboarding"

  # Dash routes для UI прототипа DeliveryTracker
  get "dash/test" => "dash#test"          # aidelivery.tech/dash/test - главная страница прототипа
  get "dash/onboarding" => "dash#onboarding"    # процесс добавления ресторана
  get "dash/dashboard" => "dash#dashboard"      # основной дашборд мониторинга
  get "dash/alerts" => "dash#alerts"            # страница уведомлений
  get "dash/settings" => "dash#settings"        # настройки уведомлений
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "landing#index"

end
