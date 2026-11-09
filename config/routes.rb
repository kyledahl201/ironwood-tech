Rails.application.routes.draw do
  root "pages#home"

  # Marketing pages
  get "about", to: "pages#about"
  get "faq", to: "pages#faq"
  get "refunds", to: "pages#refunds"
  get "terms", to: "pages#terms"
  get "privacy", to: "pages#privacy"
  get "consulting", to: "leads#new", as: :consulting
  resources :leads, only: :create
  get "unsubscribe/:token", to: "unsubscribes#show", as: :unsubscribe
  post "unsubscribe/:token", to: "unsubscribes#create"
  resources :posts, only: %i[index show], path: "blog"

  # Catalog and checkout
  resources :courses, only: %i[index show] do
    get :rubric, on: :member
    resource :checkout, only: :create
    get "checkout/success", to: "checkouts#success", as: :checkout_success
  end
  post "webhooks/stripe", to: "stripe_webhooks#create"

  # Accounts
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create], path: "signup", path_names: { new: "" }
  get "login", to: "sessions#new"

  # Student area
  get "portal", to: "portal/dashboard#show", as: :portal
  get "portal/certificates/:course_id", to: "portal/certificates#show", as: :portal_certificate
  scope "learn/:course_id", module: "learn", as: "learn" do
    resources :lessons, only: :show do
      post :complete, on: :member
      resources :tutor_messages, only: :create
    end
  end

  # Owner area
  namespace :admin do
    root "dashboard#show"
    resources :leads, only: %i[index update]
    resources :users, only: %i[index show]
    resources :enrollments, only: :create
    resources :courses, only: %i[index edit update]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
