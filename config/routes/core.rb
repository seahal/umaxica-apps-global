# typed: false
# frozen_string_literal: true

# Core owns the BFF surface.
scope module: :core, as: :core do
  # Application BFF host.
  constraints host: [ENV["CORE_SERVICE_URL"], "core.app.localhost"].compact do
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Health summary and probes.
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      # Edge compatibility API.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          # Session summary.
          resource :session, only: :show

          # Token lifecycle endpoints.
          namespace :token do
            # Token refresh endpoint.
            resource :refresh, only: :create
          end
        end
      end

      # Auth callback and RP login/logout endpoints.
      namespace :auth do
        resource :callback, only: :show

        # RP login start: redirects to Acme /oauth/authorize.
        resource :authorization, only: :show, path: ""

        # RP local logout: destroys only the local session.
        resource :logout, only: :create
      end

      # OIDC back-channel receiver.
      namespace :oidc do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end
    end
  end

  # Corporate BFF host.
  constraints host: [ENV["CORE_CORPORATE_URL"], "core.com.localhost"].compact do
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Health summary and probes.
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      # Edge compatibility API.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          # Session summary.
          resource :session, only: :show

          # Token lifecycle endpoints.
          namespace :token do
            # Token refresh endpoint.
            resource :refresh, only: :create
          end
        end
      end

      # Auth callback and RP login/logout endpoints.
      namespace :auth do
        resource :callback, only: :show

        # RP login start: redirects to Acme /oauth/authorize.
        resource :authorization, only: :show, path: ""

        # RP local logout: destroys only the local session.
        resource :logout, only: :create
      end

      # OIDC back-channel receiver.
      namespace :oidc do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end
    end
  end

  # Staff BFF host.
  constraints host: [ENV["CORE_STAFF_URL"], "core.org.localhost"].compact do
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Health summary and probes.
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      # Crawler policy endpoint.
      resources :robots, only: :index, path: "robots.txt"

      # Sitemap endpoint.
      resource :sitemap, only: :show, path: "sitemap.xml"

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Staff configuration endpoint.
      resource :configuration, only: :show

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      # Edge compatibility API.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end

      # Versioned BFF API.
      namespace :api do
        namespace :v0 do
          # Session summary.
          resource :session, only: :show

          # Token lifecycle endpoints.
          namespace :token do
            # Token refresh endpoint.
            resource :refresh, only: :create
          end
        end
      end

      # Auth callback and RP login/logout endpoints.
      namespace :auth do
        resource :callback, only: :show

        # RP login start: redirects to Acme /oauth/authorize.
        resource :authorization, only: :show, path: ""

        # RP local logout: destroys only the local session.
        resource :logout, only: :create
      end

      # OIDC back-channel receiver.
      namespace :oidc do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end
    end
  end

  # Network utility host.
  constraints host: [ENV["CORE_NETWORK_URL"], "core.net.localhost"].compact do
    scope module: :net, as: :network do
      # Thin landing endpoint.
      root to: "roots#index"

      # Health summary and probes.
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  # Developer utility host.
  constraints host: [ENV["CORE_DEVELOPER_URL"], "core.dev.localhost"].compact do
    scope module: :dev, as: :developer do
      # Thin landing endpoint.
      root to: "roots#index"

      # Health summary and probes.
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end
end
