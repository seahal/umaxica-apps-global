# typed: false
# frozen_string_literal: true

# Base owns identity, OP/Authorization Server, and Rails control-plane surfaces.
# Auth surfaces handle credential ceremonies and do not own RP authority.
scope(module: :base, as: :base) do
  # User authority gateway host. Hosts listed declaratively (DRY intentionally broken).
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host, ENV["PUBLIC_BASE_SERVICE_URL"],
           "base.app.localhost",].compact,
  ) do
    scope(module: :app, as: :app) do
      root "roots#index"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resource :dashboard, only: :show
      resource :selector, only: %i(show update)
      resource :switcher, only: %i(show update)
      resources :billings, only: :index
      resources :groups, only: %i(index show create update destroy) do
        resources :avatar_memberships, controller: :group_avatar_memberships, only: %i(create update destroy)
      end
      resources :accounts, only: %i(index show)
      resources :organizations, only: %i(index show) do
        resources :memberships, module: :organizations
      end
      resource :preference, only: :show
      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resources :emails, only: :edit
        delete "emails/:id", to: "emails#destroy", as: :email
        post "emails/:id", to: "emails#create"
        resource :language, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :pagination, only: %i(edit update)
        resource :region, only: %i(edit update)
        resource :reset, only: %i(edit destroy)
        resource :screen, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :timezone, only: %i(edit update)
      end

      namespace(:well_known, path: ".well-known") do
        get(
          "openid-configuration",
          to: "discoveries#show",
          as: :discovery,
          format: false,
        )
        resource(
          :openid_configuration, only: :show, path: "openid-configuration", controller: :discoveries,
                                 format: false,
        )
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      resource(:health, only: :show)
      namespace(:health) do
        resource(:liveness, only: :show)
        resource(:readiness, only: :show)
        resource(:startup, only: :show)
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")

      # Base owns the post-authentication sign-out confirmation flow.
      scope path: :sign do
        resource :out, controller: :sign_outs, as: :sign_out, only: %i(new edit create) do
          resource :completion, only: :show, path: "complete", module: :sign_outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)
        resource(:logout, only: %i(show create))
      end

      namespace(:oauth) do
        get("authorize", to: "authorizations#show", as: :authorization)
        resource(:authorize, only: :show, controller: :authorizations)
        resource(:token, only: :create, controller: :tokens)
        resource(:userinfo, only: :show, controller: :userinfos)
        post("revoke", to: "revocations#create", as: :revocation)
        resource(:revoke, only: :create, controller: :revocations)
      end

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end

      # Base resolves session-limit remediation before resuming OIDC/social flows.
      namespace :sign do
        namespace :in do
          resource :limitation, only: %i(show update destroy), controller: :limitations
        end
      end

      namespace(:social) do
        resource :authentication, only: [] do
          post :continue
          post :completion
        end

        get(
          "google/callback",
          to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
          as: :google_callback,
          defaults: { provider: "google" },
        )

        match(
          "apple/callback",
          to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
          via: %i(get post),
          as: :apple_callback,
          defaults: { provider: "apple" },
        )

        get(
          "failure",
          to: "/auth/app/omniauth/omniauth_callbacks#failure",
        )

        scope :google do
          get(
            "sign/in", to: "/auth/app/social/authentications#continue", as: :google_auth_in,
                       defaults: { provider: "google", intent: "login" },
          )
          get(
            "sign/up", to: "/auth/app/social/authentications#continue", as: :google_auth_up,
                       defaults: { provider: "google", intent: "login", entry: "auth_up" },
          )
        end

        scope :apple do
          get(
            "sign/in", to: "/auth/app/social/authentications#continue", as: :apple_auth_in,
                       defaults: { provider: "apple", intent: "login" },
          )
          get(
            "sign/up", to: "/auth/app/social/authentications#continue", as: :apple_auth_up,
                       defaults: { provider: "apple", intent: "login", entry: "auth_up" },
          )
        end
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
        resource :completion, only: :create
      end

      resource :identity, only: :show
      resources :avatars, only: %i(index show new edit create update)

      namespace :identity do
        namespace :mfa do
          resource :reset, only: %i(show create)
          resource :challenge, only: :show
        end

        namespace :emails do
          resource :registration, only: %i(new create edit update) do
            resource :redelivery, only: :create
          end
        end

        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end

        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :secrets, controller: :secrets, only: %i(index show new edit create update destroy) do
          resource :rotation, only: :create, module: :secrets
          resource :removal, only: :create, module: :secrets
        end

        resources :sessions, only: %i(index show destroy)
        resource :session_set, path: "sessions", only: :destroy, controller: "revocations/alls"
        resource :other_sessions, only: :destroy, controller: "revocations/others"
        namespace :sessions do
          resource :revocation, only: :create, controller: "/base/app/identity/revocations"
        end

        resources :activities, only: :index

        resource :withdrawal, only: %i(new update create edit destroy) do
          delete :session, action: :end_session
        end
        resource :withdrawal_session,
                 path: "withdrawal/session",
                 only: %i(new create),
                 controller: :withdrawal_sessions
        namespace :privacy do
          resource :erasure, only: %i(new create) do
            get :status
          end
        end
      end
    end
  end

  # Corporate authority gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_corporate.host,
           ENV["PUBLIC_BASE_CORPORATE_URL"], "base.com.localhost",].compact,
  ) do
    scope(module: :com, as: :com) do
      root "roots#index"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resource :dashboard, only: :show
      resource :selector, only: %i(show update)
      resource :switcher, only: %i(show update)
      resources :accounts, only: %i(index show)
      resources :organizations, only: %i(index show) do
        resources :memberships, module: :organizations
      end
      resource :preference, only: :show

      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resources :emails, only: :edit
        delete "emails/:id", to: "emails#destroy", as: :email
        post "emails/:id", to: "emails#create"
        resource :language, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :pagination, only: %i(edit update)
        resource :region, only: %i(edit update)
        resource :reset, only: %i(edit destroy)
        resource :screen, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :timezone, only: %i(edit update)
      end

      namespace(:well_known, path: ".well-known") do
        get(
          "openid-configuration",
          to: "discoveries#show",
          as: :discovery,
          format: false,
        )
        resource(
          :openid_configuration, only: :show, path: "openid-configuration", controller: :discoveries,
                                 format: false,
        )
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      resource(:health, only: :show)
      namespace(:health) do
        resource(:liveness, only: :show)
        resource(:readiness, only: :show)
        resource(:startup, only: :show)
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")

      # Base owns the post-authentication sign-out confirmation flow.
      scope path: :sign do
        resource :out, controller: :sign_outs, as: :sign_out, only: %i(new edit create) do
          resource :completion, only: :show, path: "complete", module: :sign_outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)
        resource(:logout, only: %i(show create))
      end

      namespace(:oauth) do
        get("authorize", to: "authorizations#show", as: :authorization)
        resource(:authorize, only: :show, controller: :authorizations)
        resource(:token, only: :create, controller: :tokens)
        resource(:userinfo, only: :show, controller: :userinfos)
        post("revoke", to: "revocations#create", as: :revocation)
        resource(:revoke, only: :create, controller: :revocations)
      end

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
        resource :completion, only: :create
      end

      resource :identity, only: :show
      namespace :identity do
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :secrets,
                  controller: :secret_credentials,
                  only: %i(index show new edit create update destroy) do
          resource :rotation, only: :create
          resource :removal, only: :create
        end
        resources :sessions, only: %i(index show destroy)
        resource :session_set, path: "sessions", only: :destroy, controller: "revocations/alls"
        resource :other_sessions, only: :destroy, controller: "revocations/others"

        resources :activities, only: :index
        resource :withdrawal, only: %i(new update create edit destroy) do
          delete :session, action: :end_session
        end
        resource :withdrawal_session,
                 path: "withdrawal/session",
                 only: %i(new create),
                 controller: :withdrawal_sessions
        namespace :privacy do
          resource :erasure, only: %i(new create) do
            get :status
          end
        end
      end
    end
  end

  # Staff authority gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host, ENV["PUBLIC_BASE_STAFF_URL"],
           "base.org.localhost",].compact,
  ) do
    scope(module: :org, as: :org) do
      root "roots#index"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resource :dashboard, only: :show
      resource :selector, only: %i(show update)
      resource :switcher, only: %i(show update)
      resource :preference, only: :show
      resource :avatar, only: %i(show edit update destroy)
      resources :organizations, only: %i(index show) do
        resources :memberships, module: :organizations
      end

      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resources :emails, only: :edit
        delete "emails/:id", to: "emails#destroy", as: :email
        post "emails/:id", to: "emails#create"
        resource :language, only: %i(edit update)
        resource :motion, only: %i(edit update)
        resource :pagination, only: %i(edit update)
        resource :region, only: %i(edit update)
        resource :reset, only: %i(edit destroy)
        resource :screen, only: %i(edit update)
        resource :theme, only: %i(edit update)
        resource :timezone, only: %i(edit update)
      end

      namespace(:well_known, path: ".well-known") do
        get(
          "openid-configuration",
          to: "discoveries#show",
          as: :discovery,
          format: false,
        )
        resource(
          :openid_configuration, only: :show, path: "openid-configuration", controller: :discoveries,
                                 format: false,
        )
        resource(:jwks, only: :show, path: "jwks.json", format: false)
      end

      resource(:health, only: :show)
      namespace(:health) do
        resource(:liveness, only: :show)
        resource(:readiness, only: :show)
        resource(:startup, only: :show)
      end

      resources(:robots, only: :index, path: "robots.txt")
      resource(:sitemap, only: :show, path: "sitemap.xml")
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")

      # Staff management areas.
      resource :configuration, only: :show
      resources :accounts, only: %i(index show)
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      namespace :support do
        resources :clients, only: [] do
          resource :session, only: :destroy, controller: "clients/sessions", path: "sessions/purge"
        end
        resources :visitors, only: [] do
          resource(
            :session_emergency_revocation,
            only: :destroy,
            controller: "visitors/sessions/emergency_revocations",
            path: "sessions/emergency_revocation",
          )
        end
      end
      resources :billing, only: :index

      # Base owns the post-authentication sign-out confirmation flow.
      scope path: :sign do
        resource :out, controller: :sign_outs, as: :sign_out, only: %i(new edit create) do
          resource :completion, only: :show, path: "complete", module: :sign_outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)
        resource(:logout, only: %i(show create))
      end

      namespace(:oauth) do
        get("authorize", to: "authorizations#show", as: :authorization)
        resource(:authorize, only: :show, controller: :authorizations)
        resource(:token, only: :create, controller: :tokens)
        resource(:userinfo, only: :show, controller: :userinfos)
        post("revoke", to: "revocations#create", as: :revocation)
        resource(:revoke, only: :create, controller: :revocations)
      end

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
        resource :completion, only: :create
      end

      resource :identity, only: :show
      namespace :identity do
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :secrets,
                  controller: :secret_credentials,
                  only: %i(index show new edit create update destroy) do
          resource :rotation, only: :create
          resource :removal, only: :create
        end
        resources :sessions, only: %i(index show destroy)
        resource :session_set, path: "sessions", only: :destroy, controller: "revocations/alls"
        resource :other_sessions, only: :destroy, controller: "revocations/others"

        resources :activities, only: :index
        resource :withdrawal, only: :show
      end
    end
  end

  constraints(host: [ENV["PRIVATE_BASE_NETWORK_URL"], "base.net.localhost"].compact) do
    scope(module: :app, as: :network) do
      resource(:health, only: :show)
      namespace(:health) do
        resource(:liveness, only: :show)
        resource(:readiness, only: :show)
        resource(:startup, only: :show)
      end
    end
    scope(module: :net, as: :network) do
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")
    end
  end

  constraints(host: [ENV["PRIVATE_BASE_DEVELOPER_URL"], "base.dev.localhost"].compact) do
    scope(module: :app, as: :developer) do
      resource(:health, only: :show)
      namespace(:health) do
        resource(:liveness, only: :show)
        resource(:readiness, only: :show)
        resource(:startup, only: :show)
      end
    end
    scope(module: :dev, as: :developer) do
      resource(:csp_violation_report, only: :create, path: "csp-violation-report")
    end
  end
end
