Rails.application.routes.draw do
  resources :posts
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "sunset_records" => "sunset_records#index", as: :sunset_records
  get "sunset_records/:id" => "sunset_records#show", as: :sunset_record

  get "/sunsets", to: "sunsets#index"
  get "/sunsets/stream", to: "sunsets#stream"

  post "sunset_records" => "sunset_records#create", as: :sunset_records_create

  # Defines the root path route ("/")
  # root "posts#index"
end
