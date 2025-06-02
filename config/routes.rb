Rails.application.routes.draw do
  devise_for :users
  root "contact_imports#index"

  resources :contact_imports do
    member do
      get :errors
    end
  end

  resources :contacts, only: [ :index, :show ]

  # Keep this for backward compatibility if needed, or remove if not using
  # resources :imports, only: [:new, :create]
end
