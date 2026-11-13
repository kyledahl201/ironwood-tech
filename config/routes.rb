Rails.application.routes.draw do
  root "pages#home"
  get "privacy", to: "pages#privacy"
  get "terms", to: "pages#terms"
  get "refunds", to: "pages#refunds"

  # The store: public sales pages for sold courses, and Stripe Checkout
  get "store", to: "store#index", as: :store
  get "store/:id", to: "store#show", as: :store_course
  post "store/:id/checkout", to: "checkouts#create", as: :store_checkout
  get "store/:id/checkout/success", to: "checkouts#success", as: :store_checkout_success
  post "webhooks/stripe", to: "stripe_webhooks#create"

  # A course that ships as one player page: enrolled students and the owner only
  get "learn/:course_id/player", to: "course_players#show", as: :course_player
  get "learn/:course_id/downloads", to: "course_players#downloads", as: :course_downloads

  # Accounts (by invite, or made while buying a course)
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create], path: "join", path_names: { new: "" }
  get "login", to: "sessions#new"

  # Student portal
  get "portal", to: "portal/dashboard#show", as: :portal
  namespace :portal do
    resources :study_sessions, only: %i[index create destroy], path: "study-log"
    post "pulse", to: "pulses#create", as: :pulse
    resource :settings, only: :update
    resource :account, only: %i[show update]
    resources :badges, only: :index
    post "eggs/:key", to: "eggs#create", as: :egg
    get "certificates/:course_id", to: "certificates#show", as: :certificate
  end

  resources :courses, only: %i[index show] do
    get :rubric, on: :member
    resource :enrollment, only: :create
  end
  scope "learn/:course_id", module: "learn", as: "learn" do
    resources :lessons, only: :show do
      post :complete, on: :member
      resources :tutor_messages, only: :create
    end
  end

  # A course's tutor kit, for the student's own Claude project
  get "classroom/kits/:course", to: "tutor_kits#show", as: :tutor_kit
  get "classroom/kits/:course/:file", to: "tutor_kits#file", as: :tutor_kit_file, constraints: { file: /[A-Za-z0-9-]+\.md/ }

  # The classroom: scripted lessons played step by step
  resources :class_lessons, only: %i[index show], path: "classroom" do
    member do
      post :progress
      post :quiz
      get :study
      post "study/card", action: :sort_card, as: :study_card
      post "study/restart", action: :restart_study, as: :study_restart
      get :homework
      post :homework, action: :hand_in
    end
    resources :tutor_messages, only: :create, path: "tutor", controller: "class_tutor_messages"
  end

  # Code lab and visualizers
  resources :exercises, only: %i[index show], path: "lab" do
    resources :attempts, only: :create
  end
  get "visualizers", to: "visualizers#index", as: :visualizers
  get "visualizers/:id", to: "visualizers#show", as: :visualizer, constraints: { id: /loop|hash|stack/ }

  # Owner area
  namespace :admin do
    root "dashboard#show"
    resources :users, only: %i[index show update]
    resources :invites, only: %i[index create destroy]
    resources :enrollments, only: %i[index create] do
      member do
        post :revoke
        post :reinstate
      end
    end
    resources :courses, only: %i[index edit update]
    resource :transcript, only: %i[show create]
    resources :exercises, only: %i[index update]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
