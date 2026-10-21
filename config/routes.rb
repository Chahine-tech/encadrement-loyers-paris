Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :districts, only: :index
      get "comparisons", to: "comparisons#show"

      namespace :reports do
        resources :districts, only: :index
        resources :zones, only: :index
      end
    end
  end
end
