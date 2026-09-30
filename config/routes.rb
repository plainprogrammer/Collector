Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions and every
  # configured database can be opened and written to, otherwise 500.
  # Used by the Docker Compose healthcheck and the Kamal proxy to verify that the app is live.
  get "up" => "health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session, only: %i[new create destroy]
  resource :collection, only: :show

  namespace :catalog do
    resources :entries, only: %i[index show], param: :external_key
    resources :identities, only: :show, param: :external_key
  end

  # Defines the root path route ("/")
  root "home#index"
end
