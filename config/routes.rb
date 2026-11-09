# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :bookings, only: %i[index show create]
    end
  end
end

# Output dari `bin/rails routes`:
#
#   Verb  URI Pattern                     Controller#Action
#   GET   /api/v1/bookings(.:format)      api/v1/bookings#index
#   POST  /api/v1/bookings(.:format)      api/v1/bookings#create
#   GET   /api/v1/bookings/:id(.:format)  api/v1/bookings#show
