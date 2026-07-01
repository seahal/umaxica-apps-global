# typed: false
# frozen_string_literal: true

# Base owns the credential gateway surfaces. Auth surfaces handle credential
# ceremonies and do not own RP authority.
scope(module: :base, as: :base) do
  # User authority gateway host. Hosts listed declaratively (DRY intentionally broken).
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_service.host, ENV["PUBLIC_BASE_SERVICE_URL"],
           "base.app.localhost",].compact,
  ) do
    scope(module: :app, as: :app) do
      root "roots#index"
      resource :dashboard, only: :show
      resources :billings, only: :index
      resources :groups, only: :index
      resource :preference, only: :show
      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resource :email, only: %i(edit update)
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

      # Canonical ceremony entrypoints and authed-out confirmation/cleanup.
      namespace :sign do
        resource :up, only: :show
        resource :in, only: :show
      end
      scope path: :sign do
        resource :out, controller: :sign_outs, as: :sign_out, only: %i(new edit create) do
          resource :completion, only: :show, path: "complete", module: :sign_outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)

        namespace(:backchannel) do
          resource(:logout, only: :create)
        end
      end

      # Public web API: OTP delivery, cookie consent, theme.
      namespace :web do
        namespace :v0 do
          namespace :in do
            namespace :email do
              resource :otp, only: :create
            end

            namespace :telephone do
              resource :otp, only: :create
            end
          end

          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Auth-up ceremony.
        namespace(:up) do
          resource(:email, only: %i(new create))
          resource(:telephone, only: %i(new create))

          namespace(:guard) do
            resource(:apple, only: :show)
            resource(:google, only: :show)
            resource(:email, only: :show)
            resource(:telephone, only: :show)
          end

          namespace(:check) do
            namespace(:apple) do
              resource(:confirmation, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:google) do
              resource(:confirmation, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:email) do
              resource(:otp, only: %i(show create update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:telephone) do
              resource(:otp, only: %i(show create update destroy))
              resource(:passkey, only: %i(show create update destroy))
              resource(:passcode, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end
          end
        end

        # Sign-in ceremony.
        namespace :in do
          resource :email, only: %i(new create edit update)

          resource :passkey, only: :new
          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end

          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)

          resource :guard, only: :show
          resource :check, only: %i(show update destroy)

          resource :challenge, only: :show
          namespace :challenge do
            resource :totp, only: %i(new create)
            resource :passkey, only: %i(new create)
          end
        end
      end

      namespace(:social) do
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
      end
      namespace :verification do
        resource :setup, only: :new
        resource :passkey, only: %i(new create)
        resource :totp, only: %i(new create)

        resources :emails, only: %i(new create edit update) do
          resource :redelivery, only: :create
        end
      end

      resource :identity, only: :show
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

        resource :withdrawal, only: %i(new update create edit destroy)
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
      resource :dashboard, only: :show
      resource :preference, only: :show
      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resource :email, only: %i(edit update)
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

      # Canonical ceremony entrypoints and authed-out confirmation.
      namespace :sign do
        resource :up, only: :show
        resource :in, only: :show
      end
      scope path: :sign do
        resource :out, controller: :sign_outs, as: :sign_out, only: %i(new edit create) do
          resource :completion, only: :show, path: "complete", module: :sign_outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)

        namespace(:backchannel) do
          resource(:logout, only: :create)
        end
      end

      # Public web API: OTP delivery, cookie consent, theme.
      namespace :web do
        namespace :v0 do
          namespace :in do
            namespace :email do
              resource :otp, only: :create
            end

            namespace :telephone do
              resource :otp, only: :create
            end
          end

          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Auth-up ceremony.
        namespace(:up) do
          resource(:email, only: %i(new create))
          resource(:telephone, only: %i(new create))

          namespace(:guard) do
            resource(:email, only: :show)
            resource(:telephone, only: :show)
          end

          namespace(:check) do
            namespace(:email) do
              resource(:otp, only: %i(show create update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end

            namespace(:telephone) do
              resource(:otp, only: %i(show create update destroy))
              resource(:passkey, only: %i(show create update destroy))
              resource(:passcode, only: %i(show update destroy))
              resource(:birthdate, only: %i(show update destroy))
            end
          end
        end

        # Sign-in ceremony.
        namespace :in do
          resource :email, only: %i(new create edit)

          resource :passkey, only: :new
          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end

          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)

          resource :guard, only: :show
          resource :check, only: %i(show update destroy)

          resource :challenge, only: :show

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
      end
      namespace :verification do
        resource :setup, only: :new
        resource :passkey, only: %i(new create)

        resources :emails, only: %i(new create edit update) do
          resource :redelivery, only: :create
        end
      end

      resource :identity, only: :show
    end
  end

  # Staff authority gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).base_staff.host, ENV["PUBLIC_BASE_STAFF_URL"],
           "base.org.localhost",].compact,
  ) do
    scope(module: :org, as: :org) do
      root "roots#index"
      resource :dashboard, only: :show
      resource :preference, only: :show
      namespace :preference do
        resource :calendar, only: %i(edit update)
        resource :clock, only: %i(edit update)
        resource :cookie, only: %i(edit update)
        resource :currency, only: %i(edit update)
        resource :density, only: %i(edit update)
        resource :email, only: %i(edit update)
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
      resources :accounts, only: :index
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      resources :billing, only: :index

      # Canonical ceremony entrypoints and authed-out confirmation.
      namespace :sign do
        resource :up, only: :show
        resource :in, only: :show
      end
      scope path: :sign do
        resource :out, controller: :sign_outs, as: :sign_out, only: %i(new edit create) do
          resource :completion, only: :show, path: "complete", module: :sign_outs
        end
      end

      namespace(:oidc) do
        resource(:authorization, only: :show)
        resource(:callback, only: :show)

        namespace(:backchannel) do
          resource(:logout, only: :create)
        end
      end

      # Public web API: cookie consent, theme.
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up and sign-in ceremonies.
      namespace :sign do
        # Staff invitation auth-up.
        namespace :up do
          resources :invitations, only: %i(new create)
        end

        # Sign-in ceremony.
        namespace :in do
          resource :passkey, only: :new

          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end

          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)

          resource :guard, only: :show
          resource :check, only: %i(show update destroy)

          resource :challenge, only: :show

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end

          # Entra ID (Microsoft) sign-in ceremony.
          # authorization: POST initiates PKCE flow and redirects to Entra.
          # callback: GET receives the authorization code from Entra.
          resource :entra, only: :new do
            post :authorization
            get :callback
          end
        end
      end

      # Step-up verification.
      resource :verification, only: :show
      namespace :verification do
        resource :cancellation, only: :create
      end
      namespace :verification do
        resource :setup, only: :new
        resource :passkey, only: %i(new create)
      end

      resource :identity, only: :show
    end
  end
end
