Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :districts, only: :index
      # One computed result per query string, not a stored resource
      get "comparisons", to: "comparisons#show"

      namespace :reports do
        resources :districts, only: :index
      end
    end
  end
end
