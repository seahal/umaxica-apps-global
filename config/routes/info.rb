# typed: false
# frozen_string_literal: true

# Info owns public informational content.
scope module: :info, as: :info do
  boot_config = Rails.configuration.x.boot_config

  # App info host.
  constraints host: [boot_config.fetch(:hosts).info_service.host, "info.app.localhost", "info.umaxica.app"].compact do
    scope module: :app, as: :app do
      root to: "roots#index"

      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Corporate info host.
  constraints host: [boot_config.fetch(:hosts).info_corporate.host, "info.com.localhost", "info.umaxica.com"].compact do
    scope module: :com, as: :com do
      root to: "roots#index"

      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Staff info host.
  constraints host: [boot_config.fetch(:hosts).info_staff.host, "info.org.localhost", "info.umaxica.org"].compact do
    scope module: :org, as: :org do
      root to: "roots#index"

      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end
end
