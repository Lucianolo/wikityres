Rails.application.routes.draw do
  
  
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete '/logout',  to: 'sessions#destroy'

  get 'welcome/index/:params' => 'welcome#index', as: :search
  
  get 'welcome/search'
  
  get 'welcome/cron_job' => 'welcome#cron_job', as: :cron_job
  
  
  root 'welcome#search'
  
  get 'profiles/index' => 'profiles#index', as: :profile
  get 'profiles/add_query/:params' => 'profiles#add_query', as: :add_query
  get 'profiles/remove_query/:id' => 'profiles#remove_query', as: :remove_query
  get 'profiles/disattiva_fornitore/:id' => 'profiles#disattiva_fornitore', as: :disattiva_fornitore
  get 'profiles/attiva_fornitore/:id' => 'profiles#attiva_fornitore', as: :attiva_fornitore
  get 'profiles/add_fornitore/:params' => 'profiles#add_fornitore', as: :add_fornitore
  
  
  
  
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
