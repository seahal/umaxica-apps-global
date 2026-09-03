# typed: false
# frozen_string_literal: true

# Palm owns the native RP and API surface.
scope module: :palm, as: :palm do
  # App native RP/API host. Hosts listed declaratively (DRY intentionally broken).
  constraints host: [Rails.configuration.x.boot_config.fetch(:hosts).palm_service.host, "palm.app.localhost"].compact do
    # App surface controllers.
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Deployment identifier endpoint.
      resource :revision, only: :show

      # Resourceful plain-text health endpoints.
      resource :health, only: :show, format: false do
        scope module: :health do
          resources :startups, only: :index, format: false
          resources :livenesses, only: :index, format: false
          resources :readinesses, only: :index, format: false
        end
      end

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # RP login start: redirects to Base /oauth/authorize.
      # Compatibility callback is a generic native stub; Base owns OAuth/OIDC.
      namespace :oidc do
        resource :authorization, only: :show
        resource :callback, only: :show
      end

      # Native sign-out notice; does not clear bearer tokens from the browser.
      namespace :sign do
        resource :termination, only: %i(show create), path: "out", controller: :outs, as: :out
      end

      # Browser CSP report sink.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # PWA offline fallback. This is the route form Rails' own application generator emits, kept
      # verbatim except for the leading slash on the controller, which escapes the enclosing
      # `scope(module:)`. Approved exception to the resourceful routing rule; do not reshape it into
      # `resource`. See adr/pwa-offline-route-exception.md.
      get("service-worker", to: "/rails/pwa#service_worker", as: :pwa_service_worker)
      get("offline", to: "/rails/pwa#offline", as: :pwa_offline)

      # Native bearer-token API.
      namespace :api do
        # Versioned native API.
        namespace :v0 do
          # Current native profile.
          resource :profile, only: :show
        end
      end
    end
  end
end
