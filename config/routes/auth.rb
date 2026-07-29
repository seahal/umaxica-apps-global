# typed: false
# frozen_string_literal: true

# Auth owns the credential gateway surfaces. Base is the sole IdP /
# Authorization Server; Auth surfaces handle credential ceremonies and do not
# own RP authority.
scope(module: :auth, as: :auth) do
  # User credential gateway host. Hosts listed declaratively (DRY intentionally broken).
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_service.host, ENV["PUBLIC_AUTH_SERVICE_URL"],
           "auth.app.localhost",].compact,
  ) do
    scope(module: :app, as: :app) do
      root "roots#index"
      resource :dashboard, only: :show
      resources :billings, only: :index

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

      namespace :apple do
        resources :notifications, only: :create
      end

      # Canonical ceremony entrypoints and authed-out confirmation/cleanup.
      namespace :sign do
        resource :registration, only: :show, path: "up", controller: :ups, as: :up
        resource :session, only: :show, path: "in", controller: :ins, as: :in
        resource :termination, only: %i(new edit create destroy), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
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

          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :status, only: :show, path: "check", controller: :checks, as: :check
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
          resource :check, only: :show

          resource :challenge, only: :show
          namespace :challenge do
            resource :totp, only: %i(new create)
            resource :passkey, only: %i(new create)
          end
        end
      end

      namespace(:social) do
        # Non-resourceful exception: OmniAuth middleware owns these fixed provider callback paths.
        get(
          "google/callback",
          to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
          as: :google_callback,
          defaults: { provider: "google" },
        )

        get(
          "apple/callback",
          to: "/auth/app/omniauth/omniauth_callbacks#omniauth",
          as: :apple_callback,
          defaults: { provider: "apple" },
        )

        get(
          "failure",
          to: "/auth/app/omniauth/omniauth_callbacks#failure",
          as: :failure,
        )

        # Ceremony start pages. session = sign-in intent, registration =
        # sign-up entry; the provider is carried by route defaults.
        scope :google, as: :google, defaults: { provider: "google", intent: "login" } do
          resource :session, only: :new, controller: :sessions
          resource :registration, only: :new, controller: :registrations, defaults: { entry: "auth_up" }
        end

        scope :apple, as: :apple, defaults: { provider: "apple", intent: "login" } do
          resource :session, only: :new, controller: :sessions
          resource :registration, only: :new, controller: :registrations, defaults: { entry: "auth_up" }
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

      # Settings and credential management.
      resource :settings, only: :show
      namespace :settings do
        resources :totps, only: %i(index new create edit update destroy)

        # TODO: cache passkeys/passkey lookups.
        resources :passkeys do
          resource :removal, only: :create
        end

        namespace :passkeys do
          resource :options, only: :create
          resource :verification, only: :create
        end

        resource :apple, only: %i(show edit create destroy)
        resource :google, only: %i(show edit create destroy)
      end
    end
  end

  # Corporate credential gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_corporate.host,
           ENV["PUBLIC_AUTH_CORPORATE_URL"], "auth.com.localhost",].compact,
  ) do
    scope(module: :com, as: :com) do
      root "roots#index"
      resource :dashboard, only: :show

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
        resource :registration, only: :show, path: "up", controller: :ups, as: :up
        resource :session, only: :show, path: "in", controller: :ins, as: :in
        resource :termination, only: %i(new edit create destroy), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
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

          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :status, only: :show, path: "check", controller: :checks, as: :check
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
          resource :check, only: :show

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

      # Settings and credential management.
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          resource :removal, only: :create
        end

        namespace :passkeys do
          resource :options, only: :create
          resource :verification, only: :create
        end
      end
    end
  end

  # Staff credential gateway host.
  constraints(
    host: [Rails.configuration.x.boot_config.fetch(:hosts).auth_staff.host, ENV["PUBLIC_AUTH_STAFF_URL"],
           "auth.org.localhost",].compact,
  ) do
    scope(module: :org, as: :org) do
      root "roots#index"
      resource :dashboard, only: :show

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
        resource :registration, only: :show, path: "up", controller: :ups, as: :up
        resource :session, only: :show, path: "in", controller: :ins, as: :in
        resource :termination, only: %i(new edit create destroy), path: "out", controller: :outs, as: :out do
          resource :completion, only: :show, path: "complete", module: :outs
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
          resource :theme, only: %i(show update)
          resource :cookie, only: %i(show update)
        end
      end

      # Edge compatibility API: token lifecycle management.
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :status, only: :show, path: "check", controller: :checks, as: :check
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
          resource :check, only: :show

          resource :challenge, only: :show

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end

          # Entra ID (Microsoft) sign-in ceremony.
          # The callback path is fixed in the Entra app registration.
          resource :entra, only: :new
          namespace :entra do
            resource :authorization, only: :create
            resource :callback, only: :show
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

      # Settings and credential management.
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          resource :removal, only: :create
        end

        namespace :passkeys do
          resource :options, only: :create
          # Passkey (WebAuthn) assertion verification for settings-level re-auth.
          resource :verification, only: :create
        end

        resource :entra, only: %i(show edit create destroy)
      end
    end
  end
end
