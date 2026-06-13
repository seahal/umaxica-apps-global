# typed: false
# frozen_string_literal: true

scope module: :help, as: :help do
  # Application help surface
  constraints host: ENV["HELP_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      resources :entries, only: %i(index show)
      namespace :edge do
        namespace :v0 do
          resources :entries, only: %i(index show)
        end
      end
    end
  end

  # Corporate help surface
  constraints host: ENV["HELP_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      resources :entries, only: %i(index show)
      namespace :edge do
        namespace :v0 do
          resources :entries, only: %i(index show)
        end
      end
    end
  end

  # Staff help surface
  constraints host: ENV["HELP_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      resources :entries, only: %i(index show)
      namespace :edge do
        namespace :v0 do
          resources :entries, only: %i(index show)
        end
      end
    end
  end
end
