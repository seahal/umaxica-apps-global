# typed: false
# frozen_string_literal: true

# Docs owns the public documentation content surface.
scope module: :docs, as: :docs do
  # App documentation host.
  constraints host: ENV["DOCS_SERVICE_URL"] do
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

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end

  # Corporate documentation host.
  constraints host: ENV["DOCS_CORPORATE_URL"] do
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

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end

  # Staff documentation host.
  constraints host: ENV["DOCS_STAFF_URL"] do
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

      # Public read-only documentation API.
      namespace :api do
        # Versioned documentation API.
        namespace :v0 do
          # Published documentation entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end
end
