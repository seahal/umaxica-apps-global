# typed: false
# frozen_string_literal: true

# News owns the public news content surface.
scope module: :news, as: :news do
  # App news host.
  constraints host: [ENV["NEWS_SERVICE_URL"], "news.jp.umaxica.app", "news.app.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end

  # Corporate news host.
  constraints host: [ENV["NEWS_CORPORATE_URL"], "news.jp.umaxica.com", "news.com.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end

  # Staff news host.
  constraints host: [ENV["NEWS_STAFF_URL"], "news.jp.umaxica.org", "news.org.localhost"].compact do
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

      # Public read-only news API.
      namespace :api do
        # Versioned news API.
        namespace :v0 do
          # Published news entries.
          resources :entries, only: %i(index show), param: :slug do
            resources :revisions, only: %i(index show), module: :entries
          end
        end
      end
    end
  end
end
