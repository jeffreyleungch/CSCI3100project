Rails.application.routes.draw do
  resources :items do
    collection do
      get 'search'
    end
  end
end