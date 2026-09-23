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

  resources :quizzes, only: %i[index show update]
  resources :schools, only: [:show] do
    scope module: :schools do
      resource :sync, only: [:create]
      resource :password_reset, only: [:create]
    end
  end
  resources :leaderboards, only: [:index]
  resources :classrooms, only: %i[show index update] do
    resources :homeworks, only: %i[new create]
  end
  resources :questions, only: %i[index edit update destroy] do
    scope module: :questions do
      resource :flag, only: %i[create destroy]
      resource :flag_reset, only: [:create]
    end
  end
  resources :subjects, only: [] do
    resources :lessons, only: [:new]
    resources :quizzes, only: %i[new create]
    resource :leaderboard, only: [:show]
    scope module: :subjects do
      resources :topics, only: %i[new create]
      resources :flagged_questions, only: [:index]
    end
  end
  resources :topics, only: %i[update destroy] do
    resource :leaderboard, only: [:show]
    scope module: :topics do
      resources :questions, only: %i[index new create]
      resource :import, only: %i[new create]
    end
  end
  resources :homeworks, only: %i[show destroy]
  resources :users, only: %i[show index update] do
    scope module: :users do
      resource :password_reset, only: [:create]
      resource :oauth_link, only: [:destroy]
    end
  end
  resources :lessons, except: %i[show new] do
    scope module: :lessons do
      resources :questions, only: [:index]
    end
  end
  resources :customisations, only: [:index], path: "shop" do
    scope module: :customisations do
      resource :unlock, only: [:create]
    end
  end

  resource :dashboard, only: [:show]

  get "/pages/*id", to: "pages#show", as: :page, format: false

  authenticated :user do
    root to: "dashboards#show", as: :authenticated_root
  end

  # if routing the root path, update for your controller
  root to: "pages#show", id: "home"
end
