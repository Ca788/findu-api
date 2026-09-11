Rails.application.routes.draw do
  # Health check
  get "/health", to: "health#show"

  devise_for :users, skip: :all

  # Named route required by Devise mailer template (edit_user_password_url).
  # The link in the email points here; the frontend should intercept and
  # call PATCH /api/v1/password with the token.
  devise_scope :user do
    get "users/password/edit", to: "api/v1/passwords#update", as: :edit_user_password
  end

  namespace :api do
    namespace :v1 do
      devise_scope :user do
        post "login", to: "sessions#create"
        delete "logout", to: "sessions#destroy"
      end

      resource :user, only: [:show, :create, :update], controller: "user"
      resource :password, only: [:create, :update], controller: "passwords"

      resources :artifacts, only: [:index, :show, :create]

      namespace :inbound do
        resources :messages, only: [:create]
      end

      namespace :financial do
        resources :categories, only: [:index, :show, :create, :update, :destroy] do
          collection { get :totals }

          resources :transactions,
                    controller: "categories/transactions",
                    only:       [:index]
        end

        resources :budgets, only: [:index, :show, :create, :update, :destroy] do
          collection do
            get :current
          end
        end

        resources :receipts, only: [:index, :show, :create] do
          member do
            post :deliver
            get  :download
          end
        end

        resources :recurrence_rules,  only: [:index, :show, :create, :update, :destroy]
        resources :installment_plans, only: [:index, :show, :create, :update, :destroy]

        resources :statements,
                  only:   [:index, :show],
                  param:  :month,
                  constraints: { month: /\d{4}-\d{2}/ } do
          resources :entries,
                    controller: "statements/entries",
                    only:       [:create, :update, :destroy] do
            member do
              post :mark_paid
              post :mark_pending
            end
          end
        end
      end

      namespace :intelligence do
        resources :insights, only: [:index]
      end

      namespace :chat do
        resources :agents, only: [:index]
        resources :models, only: [:index]
        resources :conversations, only: [:index, :show, :create, :update, :destroy] do
          resources :messages, only: [:index, :show, :create]
        end
      end
    end
  end
end
