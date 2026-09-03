# typed: false
# frozen_string_literal: true

# Info owns public informational content.
scope module: :info, as: :info do
  # App info host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).info_service.host, "info.app.localhost",
                     "info.umaxica.app",].compact do
    scope module: :app, as: :app do
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show

      resource(:health, only: :show, format: false) do
        scope(module: :health) do
          resources(:startups, only: :index, format: false)
          resources(:livenesses, only: :index, format: false)
          resources(:readinesses, only: :index, format: false)
        end
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          # `param: :slug` only renames the path segment to the public
          # identifier; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Corporate info host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).info_corporate.host, "info.com.localhost",
                     "info.umaxica.com",].compact do
    scope module: :com, as: :com do
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show

      resource(:health, only: :show, format: false) do
        scope(module: :health) do
          resources(:startups, only: :index, format: false)
          resources(:livenesses, only: :index, format: false)
          resources(:readinesses, only: :index, format: false)
        end
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          # `param: :slug` only renames the path segment to the public
          # identifier; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end

  # Staff info host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).info_staff.host, "info.org.localhost",
                     "info.umaxica.org",].compact do
    scope module: :org, as: :org do
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show

      resource(:health, only: :show, format: false) do
        scope(module: :health) do
          resources(:startups, only: :index, format: false)
          resources(:livenesses, only: :index, format: false)
          resources(:readinesses, only: :index, format: false)
        end
      end

      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      namespace :api do
        namespace :v0 do
          # `param: :slug` only renames the path segment to the public
          # identifier; the route stays fully resourceful.
          resources :entries, only: %i(index show), param: :slug
        end
      end
    end
  end
end
