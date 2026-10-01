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
  resource :registration, only: %i[new create]
  resource :collection, only: :show do
    scope module: :collections do
      resource :selection, only: %i[create update]
      resource :condition_change, only: %i[new create]
      resources :bulk_removals, only: %i[new create] do
        resource :undo, only: :create, module: :bulk_removals
      end
    end
  end
  resource :more, only: :show

  # The card scanner (spec 007): reachable by URL only until adding from the scanner ships.
  resource :scanner, only: :show
  namespace :scanner do
    resources :readings, only: :create

    # Development-only measurement mode (spec 007 Story 5); every action answers 404 when it's off.
    resource :measurement, only: :show do
      scope module: :measurements do
        resources :captures, only: :create
        resources :skips, only: :create
        resource :replay, only: %i[show create]
        resources :strips, only: :show, constraints: { id: /[\w.-]+/ }
      end
    end
  end

  namespace :catalog do
    resources :entries, only: %i[index show], param: :external_key do
      resource :quick_add, only: :create
    end
    resources :identities, only: :show, param: :external_key
  end

  scope "catalog/entries/:entry_external_key", as: :catalog_entry do
    resources :lots, only: %i[new create]
  end
  resources :lots, only: %i[edit update destroy] do
    resource :removal, only: :new, module: :lots
  end

  # The self-hosted OCR engine for the card scanner (spec 007, ADR 0001).
  get "ocr/:version/*path", to: "ocr_assets#show", as: :ocr_asset, format: false, constraints: { version: /v\d+\.\d+\.\d+/ }

  namespace :admin do
    resources :users, except: :show do
      resource :deletion, only: :new, module: :users
    end
    resource :sign_up_setting, only: :update
  end

  # Defines the root path route ("/")
  root "collections#root"
end
