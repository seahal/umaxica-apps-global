# typed: false
# frozen_string_literal: true

scope module: :jump, as: :jump do
  constraints host: ENV["JUMP_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      # Health
      resource :health, only: :show
      # Jump links
      get "to/:public_id", to: "to#show"
    end
  end

  constraints host: ENV["JUMP_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      # Health
      resource :health, only: :show
      # Jump links
      get "to/:public_id", to: "to#show"
    end
  end

  constraints host: ENV["JUMP_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      # Health
      resource :health, only: :show
      # Jump links
      get "to/:public_id", to: "to#show"
    end
  end
end
