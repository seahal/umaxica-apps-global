# typed: false
# frozen_string_literal: true

# Base owns the Rails control-plane surface.
scope module: :base, as: :base do
  # App control-plane host.
  constraints host: [ENV["BASE_SERVICE_URL"], "base.app.localhost"].compact do
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

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Canonical browser sign-out flow.
      resource :sign_out, only: %i(show create), path: "sign/out"

      # RP login start: redirects to Acme /oauth/authorize.
      namespace :oidc do
        resource :authorization, only: :show, path: ""
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Corporate control-plane host.
  constraints host: [ENV["BASE_CORPORATE_URL"], "base.com.localhost"].compact do
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

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Canonical browser sign-out flow.
      resource :sign_out, only: %i(show create), path: "sign/out"

      # RP login start: redirects to Acme /oauth/authorize.
      namespace :oidc do
        resource :authorization, only: :show, path: ""
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Staff control-plane host.
  constraints host: [ENV["BASE_STAFF_URL"], "base.org.localhost"].compact do
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

      # Crawler policy endpoint; keep fixed public path.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint; keep fixed public path.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # Control-plane settings index.
      resource :settings, only: :show

      # Canonical browser sign-out flow.
      resource :sign_out, only: %i(show create), path: "sign/out"

      # RP login start: redirects to Acme /oauth/authorize.
      namespace :oidc do
        resource :authorization, only: :show, path: ""
      end

      # Browser CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
