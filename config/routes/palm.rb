# typed: false
# frozen_string_literal: true

# Palm owns the native API surface.
scope module: :palm, as: :palm do
  # App native API host.
  constraints host: [ENV["PALM_SERVICE_URL"], "palm.app.localhost"].compact do
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

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # RP login start: redirects to Acme /oauth/authorize.
      namespace :oidc do
        resource :authorization, only: :show, path: ""
      end

      # Native sign-out notice; does not clear bearer tokens from the browser.
      resource :sign_out, only: %i(show create), path: "sign/out"

      # Browser CSP report sink.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Native bearer-token API.
      namespace :api do
        # Versioned native API.
        namespace :v0 do
          # Current native profile.
          resource :profile, only: :show
        end
      end

      # Compatibility callbacks only; Acme owns OAuth/OIDC.
      namespace :oidc do
        # Generic native callback stub.
        resource :callback, only: :show
      end
    end
  end
end
