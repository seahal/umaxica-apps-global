# typed: false
# frozen_string_literal: true

# Help owns the public help content surface.
scope module: :help, as: :help do
  # App help host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).help_service.host].compact do
    # App surface controllers.
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Basic health summary.
      resource :health, only: :show

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show

        # Dependency readiness probe.
        resource :readiness, only: :show

        # Boot/startup probe.
        resource :startup, only: :show
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only help API.
      namespace :api do
        # Versioned help API.
        namespace :v0 do
          # Published help entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end

  # Corporate help host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).help_corporate.host].compact do
    # Corporate surface controllers.
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Basic health summary.
      resource :health, only: :show

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show

        # Dependency readiness probe.
        resource :readiness, only: :show

        # Boot/startup probe.
        resource :startup, only: :show
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only help API.
      namespace :api do
        # Versioned help API.
        namespace :v0 do
          # Published help entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end

  # Staff help host.
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).help_staff.host].compact do
    # Staff surface controllers.
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Basic health summary.
      resource :health, only: :show

      # Machine-readable health probes.
      namespace :health do
        # Process liveness probe.
        resource :liveness, only: :show

        # Dependency readiness probe.
        resource :readiness, only: :show

        # Boot/startup probe.
        resource :startup, only: :show
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public read-only help API.
      namespace :api do
        # Versioned help API.
        namespace :v0 do
          # Published help entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end
end
