# typed: false
# frozen_string_literal: true

# Acme owns the OP/Authorization Server and durable identity/session authority.
scope module: :acme, as: :acme do
  # App OP/AS host.
  constraints host: [ENV["ACME_SERVICE_URL"], "app.localhost", "www.app.localhost"].compact do
    scope module: :app, as: :app do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known OP metadata and keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false

        # OIDC discovery endpoint; keep protocol path.
        resource :discovery, only: :show, path: "openid-configuration", format: false
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

      # Post-login landing page; keep welcome_entry alias for cross-service URL construction.
      resource :welcome, only: :show, as: :welcome_entry

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Current actor/context selector.
      resource :selector, only: %i(show update)

      # Verification ceremony entrypoint.
      resource :verification, only: :show do
        post :completion
      end

      # Preference settings entrypoint.
      resource :preference, only: [:show]
      namespace :preference do
        resource :region, only: %i(edit update)
        resource :timezone, only: %i(edit update)
        resource :language, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :date, only: %i(edit update)
        resource :time, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :density, only: %i(edit update)
        resource :page_size, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :reset, only: %i(edit destroy)
        resources :emails, only: %i(edit destroy)
        post "emails/:id", to: "emails#create"
      end

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

          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
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

      # Social authentication ceremony.
      namespace :social do
        resources :authentications,
                  only: [],
                  path: "auth" do
          post :continue, on: :member
          post :completion, on: :member
        end
      end

      # OIDC end-session endpoint.
      namespace :oidc do
        resource :logout, only: %i(show create)
      end

      # OAuth/OIDC protocol endpoints.
      namespace :oauth do
        # OAuth authorization endpoint; keep protocol path.
        resource :authorization, only: :show, path: "authorize"

        # OAuth token endpoint.
        resource :token, only: :create

        # OAuth userinfo endpoint; keep protocol path.
        resource :userinfo, only: :show

        # OAuth revocation endpoint; keep protocol path.
        resource :revocation, only: :create, path: "revoke"

        # OAuth JWKS endpoint.
        resource :jwks, only: :show
      end

      # Sign-out bridge to credential gateway.
      namespace :sign do
        resource :out, only: %i(show edit create destroy)
      end

      # Current avatar entrypoint.
      resource :avatar, only: :show

      # Current identity entrypoint.
      resource :identity, only: :show

      # Current organization entrypoint.
      resource :organization, only: :show

      # Current account entrypoint.
      resource :account, only: :show

      # Account and credential settings.
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys, only: %i(index show edit update destroy) do
          post :enrollment, on: :collection
        end

        resources :totps, only: %i(index edit update destroy) do
          post :enrollment, on: :collection
        end

        resources :secret_credentials, only: %i(index show edit update destroy) do
          post :enrollment, on: :collection
        end

        resources :emails, only: %i(index edit update destroy)
        namespace :emails do
          resource :registration, only: :create
        end

        resources :telephones, only: %i(index destroy)
        namespace :telephones do
          resource :registration, only: :create
        end

        resources :connections, only: %i(index show destroy) do
          post "social/:provider/link", action: :social_link, on: :collection, as: :social_link
          delete "social/:provider", action: :social_unlink, on: :collection, as: :social_unlink
        end

        resources :activities, only: :index

        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end

        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Corporate OP/AS host.
  constraints host: [ENV["ACME_CORPORATE_URL"], "com.localhost", "www.com.localhost"].compact do
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known OP metadata and keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false

        # OIDC discovery endpoint; keep protocol path.
        resource :discovery, only: :show, path: "openid-configuration", format: false
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

      # Post-login landing page; keep welcome_entry alias for cross-service URL construction.
      resource :welcome, only: :show, as: :welcome_entry

      # Current actor/context selector.
      resource :selector, only: %i(show update)

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Verification ceremony entrypoint.
      resource :verification, only: :show do
        post :completion
      end

      # Preference settings entrypoint.
      resource :preference, only: [:show]
      namespace :preference do
        resource :region, only: %i(edit update)
        resource :timezone, only: %i(edit update)
        resource :language, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :date, only: %i(edit update)
        resource :time, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :density, only: %i(edit update)
        resource :page_size, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :reset, only: %i(edit destroy)
        resources :emails, only: %i(edit destroy)
        post "emails/:id", to: "emails#create"
      end

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

          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
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

      # OIDC end-session endpoint.
      namespace :oidc do
        resource :logout, only: %i(show create)
      end

      # OAuth/OIDC protocol endpoints.
      namespace :oauth do
        # OAuth authorization endpoint; keep protocol path.
        resource :authorization, only: :show, path: "authorize"

        # OAuth token endpoint.
        resource :token, only: :create

        # OAuth userinfo endpoint; keep protocol path.
        resource :userinfo, only: :show

        # OAuth revocation endpoint; keep protocol path.
        resource :revocation, only: :create, path: "revoke"

        # OAuth JWKS endpoint.
        resource :jwks, only: :show
      end

      # Sign-out bridge to credential gateway.
      namespace :sign do
        resource :out, only: %i(show edit create destroy)
      end

      # Current identity entrypoint.
      resource :identity, only: :show

      # Current account entrypoint.
      resource :account, only: :show

      # Account and credential settings.
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys, only: %i(index show edit update destroy) do
          post :enrollment, on: :collection
        end

        resources :secret_credentials, only: %i(index show edit update destroy) do
          post :enrollment, on: :collection
        end

        resources :emails, only: %i(index edit update destroy)
        namespace :emails do
          resource :registration, only: :create
        end

        resources :telephones, only: %i(index destroy)
        namespace :telephones do
          resource :registration, only: :create
        end

        resources :connections, only: %i(index show destroy)
        resources :activities, only: :index

        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end

        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Staff OP/AS host.
  constraints host: [ENV["ACME_STAFF_URL"], "org.localhost", "www.org.localhost"].compact do
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known OP metadata and keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false

        # OIDC discovery endpoint; keep protocol path.
        resource :discovery, only: :show, path: "openid-configuration", format: false
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

      # Post-login landing page; keep welcome_entry alias for cross-service URL construction.
      resource :welcome, only: :show, as: :welcome_entry

      # Current actor/context selector.
      resource :selector, only: %i(show update)

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Staff configuration endpoint.
      resource :configuration, only: :show

      # Staff management areas.
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index

      namespace :support do
        resources :clients, only: [] do
          resource :sessions, only: [], controller: "client_sessions" do
            delete :purge
            delete :emergency_revoke
          end
        end

        resources :visitors, only: [] do
          resource :sessions, only: [], controller: "visitor_sessions" do
            delete :purge
            delete :emergency_revoke
          end
        end

        resources :operators, only: [] do
          resource :sessions, only: [], controller: "operator_sessions" do
            delete :purge
            delete :emergency_revoke
          end
        end
      end

      resources :billing, only: :index

      # Verification ceremony entrypoint.
      resource :verification, only: :show do
        post :completion
      end

      # Preference settings entrypoint.
      resource :preference, only: [:show]
      namespace :preference do
        resource :region, only: %i(edit update)
        resource :timezone, only: %i(edit update)
        resource :language, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :date, only: %i(edit update)
        resource :time, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :density, only: %i(edit update)
        resource :page_size, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :reset, only: %i(edit destroy)
        resources :emails, only: %i(edit destroy)
        post "emails/:id", to: "emails#create"
      end

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

          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
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

      # OIDC end-session endpoint.
      namespace :oidc do
        resource :logout, only: %i(show create)
      end

      # OAuth/OIDC protocol endpoints.
      namespace :oauth do
        # OAuth authorization endpoint; keep protocol path.
        resource :authorization, only: :show, path: "authorize"

        # OAuth token endpoint.
        resource :token, only: :create

        # OAuth userinfo endpoint; keep protocol path.
        resource :userinfo, only: :show

        # OAuth revocation endpoint; keep protocol path.
        resource :revocation, only: :create, path: "revoke"

        # OAuth JWKS endpoint.
        resource :jwks, only: :show
      end

      # Sign-out bridge to credential gateway.
      namespace :sign do
        resource :out, only: %i(show edit create destroy)
      end

      # Current avatar entrypoint.
      resource :avatar, only: :show

      # Current identity entrypoint.
      resource :identity, only: :show

      # Current organization entrypoint.
      resource :organization, only: :show

      # Current account entrypoint.
      resource :account, only: :show

      # Account and credential settings.
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys, only: %i(index show edit update destroy) do
          post :enrollment, on: :collection
        end

        resources :secret_credentials, only: %i(index show edit update destroy) do
          post :enrollment, on: :collection
        end

        resources :emails, only: %i(index edit update destroy)
        namespace :emails do
          resource :registration, only: :create
        end

        resources :telephones, only: %i(index destroy)
        namespace :telephones do
          resource :registration, only: :create
        end

        resources :connections, only: %i(index show destroy)
        resources :activities, only: :index

        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end

        resource :withdrawal, only: :show
      end
    end
  end

  # Network utility host.
  constraints host: ENV["ACME_NETWORK_URL"] do
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
  constraints host: ENV["ACME_DEVELOPER_URL"] do
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

      # Job monitoring dashboard.
      mount MissionControl::Jobs::Engine, at: "/jobs"

      # Rails DB dashboard.
      mount RailsDb::Engine, at: "/db"
    end
  end
end
