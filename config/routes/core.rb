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

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :authorization, only: :show, to: "/core/app/auth/authorizations#show"
        resource :callback, only: :show, to: "/core/app/auth/callbacks#show"

        # RP back-channel receiver.
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out flow.
      resource :sign_out, only: %i(show create), path: "sign/out"
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

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :callback, only: :show, to: "/core/com/auth/callbacks#show"
        resource :authorization, only: :show, to: "/core/com/auth/authorizations#show"

        # RP back-channel receiver.
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out flow.
      resource :sign_out, only: %i(show create), path: "sign/out"
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

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :callback, only: :show, to: "/core/org/auth/callbacks#show"
        resource :authorization, only: :show, to: "/core/org/auth/authorizations#show"

        # RP back-channel receiver.
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Canonical browser sign-out flow.
      resource :sign_out, only: %i(show create), path: "sign/out"
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
