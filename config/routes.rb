# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :admins, controllers: {invitations: "system/invitations"}
  devise_for :users, controllers: {omniauth_callbacks: "users/omniauth_callbacks"}

  namespace :system do
    root to: "overview#show"

    resources :school_groups, except: %i[show]
    resources :subjects, except: %i[show destroy] do
      scope module: :subjects do
        resource :activation, only: %i[create destroy]
      end
    end
    resources :customisations, except: %i[show destroy]
    resource :customisation_statistics, only: [:show], path: "customisations/statistics"
    resources :schools do
      scope module: :schools do
        resources :staff, only: [:index]
        resource :sync, only: [:create]
      end
    end
    resource :maintenance, only: [:show], controller: "maintenance" do
      scope module: :maintenance do
        resource :year_reset, only: [:create]
      end
    end
    resource :impersonation, only: %i[create destroy]
    resources :admins, only: %i[index destroy]
    resources :users, only: %i[index show] do
      scope module: :users do
        resources :roles, only: %i[create destroy]
        resource :email, only: [:update]
        resource :welcome_email, only: [:create]
      end
    end
  end

  resources :quizzes
  resources :schools, only: [] do
    member do
      patch :sync
      patch :reset_all_passwords
    end
  end
  resources :leaderboard, only: %i[show index]
  resources :classrooms, only: %i[show index update]
  resources :questions do
    collection do
      get "topic"
      get "lesson"
      get "download_topic"
      get "import_topic"
      get "flagged_questions"
      post "import"
    end
    member do
      patch "reset_flags"
    end
  end
  resources :topics, only: %i[create update destroy]
  resources :homeworks
  resources :users, only: %i[show index update] do
    member do
      patch "reset_password"
      delete "unlink_oauth_account"
    end
  end
  resources :flagged_questions, only: [:create]
  resources :lessons
  resources :customisations, only: [] do
    collection do
      get "show_available"
    end
    member do
      post "buy"
    end
  end

  get "quizzes/new/:subject", to: "quizzes#new"
  get "dashboard/", to: "dashboard#show"

  get "/pages/*id", to: "pages#show", as: :page, format: false

  authenticated :user do
    root to: "dashboard#show", as: :authenticated_root
  end

  # if routing the root path, update for your controller
  root to: "pages#show", id: "home"
end
