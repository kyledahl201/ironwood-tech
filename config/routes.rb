Rails.application.routes.draw do
  root "pages#home"
  get "privacy", to: "pages#privacy"

  # Accounts (invite-only)
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create], path: "join", path_names: { new: "" }
  get "login", to: "sessions#new"

  # Student portal
  get "portal", to: "portal/dashboard#show", as: :portal
  namespace :portal do
    resources :study_sessions, only: %i[index create destroy], path: "study-log"
    resource :settings, only: :update
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

  # The classroom: scripted lessons played step by step
  resources :class_lessons, only: %i[index show], path: "classroom" do
    member do
      post :progress
      post :quiz
    end
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
    resources :users, only: %i[index show]
    resources :invites, only: %i[index create destroy]
    resources :enrollments, only: :create
    resources :courses, only: %i[index edit update]
    resource :transcript, only: %i[show create]
    resources :exercises, only: %i[index update]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
