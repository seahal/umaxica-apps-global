# typed: false
# frozen_string_literal: true

# Acme owns the OP/Authorization Server and durable identity/session authority.
scope module: :acme, as: :acme do
  boot_config = Rails.configuration.x.boot_config

  # App OP/AS host.
  constraints host: [boot_config.fetch(:hosts).acme_service.host, "acme.app.localhost"].compact do
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

      # End-user preference settings index.
      resource :preference, only: [:show]
      # End-user preference setting edit/update routes.
      namespace :preference do
        # Regional presentation preference, such as country or locale region.
        resource :region, only: %i(edit update)
        # IANA time zone preference used for localizing instants.
        resource :timezone, only: %i(edit update)
        # Interface language preference.
        resource :language, only: %i(edit update)
        # Currency display preference.
        resource :currency, only: %i(edit update)
        # Date presentation preference, such as calendar/date format.
        resource :calendar, only: %i(edit update)
        # Time-of-day presentation preference, such as 12h/24h clock format.
        resource :clock, only: %i(edit update)
        # Reduced-motion or animation preference.
        resource :motion, only: %i(edit update)
        # UI density preference for compact or spacious layouts.
        resource :density, only: %i(edit update)
        # Pagination preference for default item count per paginated view.
        resource :pagination, only: %i(edit update)
        # Visual theme preference.
        resource :theme, only: %i(edit update)
        # Cookie consent and cookie behavior preference.
        resource :cookie, only: %i(edit update)
        # Preference reset endpoint.
        resource :reset, only: %i(edit destroy)
        # Email preference removal/editing endpoints.
        resources :emails, only: %i(edit destroy)
        # Email preference registration/update endpoint using an existing email identifier.
        post "emails/:id", to: "emails#create"
      end

      # Context selector for the authenticated client: resolves which
      # account/organization context the principal acts in. This is identity/session
      # context resolution (Acme authority), not a credential ceremony (Sign), and it
      # runs on the :private tier -- identity-authenticated but context not yet selected.
      resource :selector, only: %i(show update)

      # Post-login context switcher for selected actors on the app surface. Selector owns the
      # ceremony-time first selection; switcher only runs after full access is established and
      # only swaps the current account / organization / avatar context.
      resource :switcher, only: %i(show update)

      # Post-login landing page; keep welcome_entry alias for cross-service URL construction.
      resource :welcome, only: :show, as: :welcome_entry

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Verification ceremony entrypoint.
      resource :verification, only: :show do
        post :completion
        post :cancellation
      end

      # TODO: I want to merge them, and rename them to api.
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

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :authorization, only: :show, to: "/acme/app/auth/authorizations#show"
        resource :callback, only: :show, to: "/acme/app/auth/callbacks#show"
        resource :logout, only: %i(show create)
      end

      # Social authentication ceremony.
      namespace :social do
        resources :authentications,
                  only: [],
                  path: "ceremonies" do
          post :continue, on: :member
          post :completion, on: :member
        end
      end

      # Acme sign-in limitation ceremony for session-limit resolution.
      scope path: "sign/in", module: "sign/in", as: :sign_in do
        resource :limitation, only: %i(show update destroy)
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
      end

      # Canonical browser sign-out flow.
      scope path: :sign, module: :sign do
        resource :out, only: %i(new edit create), as: :sign_out do
          get :complete, on: :collection
        end
      end

      # Current identity entrypoint.
      resource :identity, only: :show
      namespace :identity do
        resources :emails, only: %i(index edit update destroy)

        namespace :emails do
          resource :registration, only: %i(new create edit update) do
            resource :redelivery, only: :create
          end
        end

        resources :telephones, only: %i(index new create edit destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end

        resource :birthdate, only: :show
        resource :recovery_secret, only: :show, path: "recovery-secret"

        resources :secrets, only: %i(index show new edit create update destroy) do
          resource :rotation, only: :create
          resource :removal, only: :create
        end

        resources :sessions, only: %i(index show) do
          resource :revocation, only: :create
        end

        namespace :revocations do
          resource :others, only: :create
          resource :all, only: :create
        end

        resources :activities, only: :index
        resource :withdrawal, only: %i(new create edit update destroy)

        namespace :mfa do
          resource :challenge, only: %i(show update)
          resource :reset, only: %i(show create)
        end
      end

      # Account / Organization / Avatar entity management (plural CRUD). Current-context
      # display and switching is consolidated into /switcher; there are intentionally no
      # singular current routes (/account, /organization, /avatar) on the app surface.
      resources :accounts, only: %i(index new create show edit update)

      # Organizations owned or visible to the current actor.
      resources :organizations, only: %i(index new create show edit update) do
        resources :memberships, only: %i(index new create edit update destroy), module: :organizations
      end

      resources :avatars, only: %i(index new create show edit update)
    end
  end

  # Corporate OP/AS host.
  constraints host: [boot_config.fetch(:hosts).acme_corporate.host, "acme.com.localhost"].compact do
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

      # Context selector for the authenticated visitor: resolves which
      # account/organization context the principal acts in. Identity/session context
      # resolution (Acme authority), not a credential ceremony (Sign); runs on :private.
      resource :selector, only: %i(show update)

      # Post-login context switcher for selected actors on the com surface.
      resource :switcher, only: %i(show update)

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Verification ceremony entrypoint.
      resource :verification, only: :show do
        post :completion
        post :cancellation
      end

      # End-user preference settings index.
      resource :preference, only: [:show]
      # End-user preference setting edit/update routes.
      namespace :preference do
        # Regional presentation preference, such as country or locale region.
        resource :region, only: %i(edit update)
        # IANA time zone preference used for localizing instants.
        resource :timezone, only: %i(edit update)
        # Interface language preference.
        resource :language, only: %i(edit update)
        # Currency display preference.
        resource :currency, only: %i(edit update)
        # Date presentation preference, such as calendar/date format.
        resource :calendar, only: %i(edit update)
        # Time-of-day presentation preference, such as 12h/24h clock format.
        resource :clock, only: %i(edit update)
        # Reduced-motion or animation preference.
        resource :motion, only: %i(edit update)
        # UI density preference for compact or spacious layouts.
        resource :density, only: %i(edit update)
        # Pagination preference for default item count per paginated view.
        resource :pagination, only: %i(edit update)
        # Visual theme preference.
        resource :theme, only: %i(edit update)
        # Cookie consent and cookie behavior preference.
        resource :cookie, only: %i(edit update)
        # Preference reset endpoint.
        resource :reset, only: %i(edit destroy)
        # Email preference removal/editing endpoints.
        resources :emails, only: %i(edit destroy)
        # Email preference registration/update endpoint using an existing email identifier.
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

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :callback, only: :show, to: "/acme/com/auth/callbacks#show"
        resource :authorization, only: :show, to: "/acme/com/auth/authorizations#show"
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
      end

      # Canonical browser sign-out flow.
      scope path: :sign, module: :sign do
        resource :out, only: %i(new edit create), as: :sign_out do
          get :complete, on: :collection
        end
      end

      # Current identity entrypoint.
      resource :identity, only: :show

      # Current organization entrypoint.
      resource :organization, only: %i(show edit update), as: :current_organization

      # Current account entrypoint.
      resource :account, only: %i(show edit update)

      # Organizations owned or visible to the current actor.
      resources :organizations, only: %i(index show new create edit update) do
        # Keep membership URLs nested under organizations while routing to the surface-local
        # organizations/memberships controller namespace.
        resources :memberships, only: %i(index new create edit update destroy), module: :organizations
      end
    end
  end

  # Staff OP/AS host.
  constraints host: [boot_config.fetch(:hosts).acme_staff.host, "acme.org.localhost"].compact do
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known OP metadata and keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false

        # TODO: I cannot agree with the naming. wtf discovery?
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

      # Context selector for the authenticated operator: resolves which
      # account/organization context the principal acts in. Identity/session context
      # resolution (Acme authority), not a credential ceremony (Sign); runs on :private.
      resource :selector, only: %i(show update)

      # Post-login context switcher for selected actors on the org surface.
      resource :switcher, only: %i(show update)

      # Signed-in dashboard.
      resource :dashboard, only: :show

      # Staff configuration endpoint.
      resource :configuration, only: :show

      # Staff management areas.
      # IAM
      resources :iam, only: :index
      # System configuration
      resources :system, only: :index
      # Audit panel
      resources :audit, only: :index
      # TODO: Do we need support entrypoint here?
      resources :support, only: :index

      namespace :support do
        resources :clients, only: [] do
          scope module: :clients do
            resource :session, only: [], path: "sessions" do
              delete :purge
              delete :emergency_revoke
            end
          end
        end

        resources :visitors, only: [] do
          scope module: :visitors do
            resource :session, only: [], path: "sessions" do
              delete :purge
              delete :emergency_revoke
            end
          end
        end

        resources :operators, only: [] do
          scope module: :operators do
            resource :session, only: [], path: "sessions" do
              delete :purge
              delete :emergency_revoke
            end
          end
        end
      end

      resources :billing, only: :index

      # Verification ceremony entrypoint.
      resource :verification, only: :show do
        post :completion
        post :cancellation
      end

      # End-user preference settings index.
      resource :preference, only: [:show]
      # End-user preference setting edit/update routes.
      namespace :preference do
        # Regional presentation preference, such as country or locale region.
        resource :region, only: %i(edit update)
        # IANA time zone preference used for localizing instants.
        resource :timezone, only: %i(edit update)
        # Interface language preference.
        resource :language, only: %i(edit update)
        # Currency display preference.
        resource :currency, only: %i(edit update)
        # Date presentation preference, such as calendar/date format.
        resource :calendar, only: %i(edit update)
        # Time-of-day presentation preference, such as 12h/24h clock format.
        resource :clock, only: %i(edit update)
        # Reduced-motion or animation preference.
        resource :motion, only: %i(edit update)
        # UI density preference for compact or spacious layouts.
        resource :density, only: %i(edit update)
        # Pagination preference for default item count per paginated view.
        resource :pagination, only: %i(edit update)
        # Visual theme preference.
        resource :theme, only: %i(edit update)
        # Cookie consent and cookie behavior preference.
        resource :cookie, only: %i(edit update)
        # Preference reset endpoint.
        resource :reset, only: %i(edit destroy)
        # Email preference removal/editing endpoints.
        resources :emails, only: %i(edit destroy)
        # Email preference registration/update endpoint using an existing email identifier.
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

      # RP OIDC entrypoints.
      namespace :oidc do
        resource :callback, only: :show, to: "/acme/org/auth/callbacks#show"
        resource :authorization, only: :show, to: "/acme/org/auth/authorizations#show"
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
      end

      # Canonical browser sign-out flow.
      scope path: :sign, module: :sign do
        resource :out, only: %i(new edit create), as: :sign_out do
          get :complete, on: :collection
        end
      end

      # Current identity entrypoint.
      resource :identity, only: :show

      # Current organization entrypoint.
      resource :organization, only: %i(show edit update), as: :current_organization

      # Current avatar entrypoint.
      resource :avatar, only: %i(show edit update destroy)

      # Current account entrypoint.
      resource :account, only: %i(show edit update)

      # Organizations owned or visible to the current actor.
      resources :organizations, only: %i(index show new create edit update) do
        resources :memberships, only: %i(index new create edit update destroy), module: :organizations
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
