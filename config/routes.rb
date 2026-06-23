# frozen_string_literal: true

Rails.application.routes.draw do
  mount SolidObserver::Engine, at: '/solid_observer'
  # API Documentation with RSwag
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # API Routes - Streamlined Design (80/20 Rule)
  namespace :api do
    namespace :v1 do
      # Inbox endpoints - Core messaging functionality
      resource :inbox, only: [] do
        collection do
          get :messages        # GET /api/v1/inbox/messages - All received messages
          get :conversations   # GET /api/v1/inbox/conversations - Conversation threads
          get :unread          # GET /api/v1/inbox/unread - Unread messages for notifications
        end
      end

      # Outbox endpoints - Essential send functionality only
      resource :outbox, only: [] do
        collection do
          post :send_message, path: 'messages' # POST /api/v1/outbox/messages - Send new message
        end
      end

      # Message management endpoints
      resources :messages, only: [:update] # PATCH /api/v1/messages/:id - Update message status

      # Health check endpoint
      get :health, to: 'health#show'
    end
  end

  # Health check endpoint for deployment monitoring (Kamal)
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Web Routes
  root to: 'messages#index'

  # Main messaging routes
  get 'inbox', to: 'messages#inbox', as: :inbox
  get 'outbox', to: 'messages#outbox', as: :outbox

  resources :messages do
    collection do
      post :mark_all_read
    end
  end

  # Prescription management routes
  resources :prescriptions, only: %i[index create] do
    member do
      post :retry_payment
      post :generate
    end
  end

  # Demo user switching routes (enabled in all environments for demo purposes)
  scope :demo do
    post 'switch_to_patient', to: 'user_switching#switch_to_patient', as: :switch_to_patient
    post 'switch_to_doctor', to: 'user_switching#switch_to_doctor', as: :switch_to_doctor
    post 'switch_to_admin', to: 'user_switching#switch_to_admin', as: :switch_to_admin
    post 'clear_user_switch', to: 'user_switching#clear_user_switch', as: :clear_user_switch
  end
end
