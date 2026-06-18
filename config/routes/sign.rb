# typed: false
# frozen_string_literal: true

# Sign owns the credential gateway surface.
scope module: :sign, as: :sign do
  boot_config = Rails.configuration.x.boot_config

  # User credential gateway host.
  constraints host: boot_config.fetch(:hosts).sign_service.host do
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

      # Canonical ceremony entrypoints.
      resource :sign_up, only: :show, path: "sign/up", controller: "sign/up"
      resource :sign_in, only: :show, path: "sign/in", controller: "sign/in"

      # Signed-out landing page.
      namespace :signed, path: "" do
        resource :out, only: :show, path: "signed-out"
      end

      # OIDC back-channel receiver.
      scope module: :oidc, path: "oidc" do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # Dashboard.
      resource :dashboard, only: :show

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
        # Sign-up ceremony.
        namespace :up do
          resource :email, only: %i(new create)
          resource :telephone, only: %i(new create)

          namespace :guard do
            resource :apple, only: :show
            resource :google, only: :show
            resource :email, only: :show
            resource :telephone, only: :show
          end

          namespace :check do
            namespace :apple do
              resource :confirmation, only: %i(show update)
              resource :birthdate, only: %i(show update)
              resource :cancellation, only: :create
            end

            namespace :google do
              resource :confirmation, only: %i(show update)
              resource :birthdate, only: %i(show update)
              resource :cancellation, only: :create
            end

            namespace :email do
              resource :otp, only: %i(show create update)
              resource :birthdate, only: %i(show update)
              resource :cancellation, only: :create
            end

            namespace :telephone do
              resource :otp, only: %i(show create update)
              resource :passkey, only: %i(show create update)
              resource :passcode, only: %i(show update)
              resource :birthdate, only: %i(show update)
              resource :cancellation, only: :create
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

          namespace :session do
            resource :cancellation, only: :create
          end

          resource :guard, only: :show
          resource :check, only: %i(show update)

          namespace :check do
            resource :cancellation, only: :create
          end

          resource :challenge, only: :show
          namespace :challenge do
            resource :totp, only: %i(new create)
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Social connection lifecycle.
      namespace :social do
        namespace :apple do
          resource :connection, only: %i(show create)
          resource :disconnection, only: :create
        end

        namespace :google do
          resource :connection, only: %i(show create)
          resource :disconnection, only: :create
        end
      end

      # OmniAuth callbacks.
      namespace :auth, path: "auth" do
        # RP login start: redirects to Acme /oauth/authorize.
        resource :authorization, only: :show, path: ""

        resource :callback, only: :show

        # RP local logout: destroys only the local session.
        resource :logout, only: :create

        # OmniAuth callback; keep provider path and defaults.
        get "google_app/callback",
            to: "omniauth_callbacks#omniauth",
            as: :google_app_callback,
            defaults: { provider: "google_app" }

        # Apple callback; keep GET/POST for provider response modes.
        match "apple/callback",
              to: "omniauth_callbacks#omniauth",
              via: %i(get post),
              as: :apple_callback,
              defaults: { provider: "apple" }

        # OmniAuth failure callback.
        get "failure",
            to: "omniauth_callbacks#failure"
      end

      # Step-up verification.
      resource :verification, only: :show
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
        namespace :mfa do
          resource :reset, only: %i(show create)
          resource :challenge, only: :show
        end

        resources :totps, only: %i(index new create edit update destroy)

        resources :passkeys do
          resource :removal, only: :create
        end

        namespace :passkeys do
          resource :options, only: :create
          resource :verification, only: :create
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
        resource :apple, only: :show
        resource :google, only: :show
        resource :secrets, only: :show

        resources :secret_credentials, only: %i(index show new edit create update destroy) do
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
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Corporate credential gateway host.
  constraints host: boot_config.fetch(:hosts).sign_corporate.host do
    scope module: :com, as: :com do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Dashboard.
      resource :dashboard, only: :show

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

      # Canonical ceremony entrypoints.
      resource :sign_up, only: :show, path: "sign/up", controller: "sign/up"
      resource :sign_in, only: :show, path: "sign/in", controller: "sign/in"

      # Auth callback and RP login/logout endpoints.
      namespace :auth, path: "auth" do
        # RP login start: redirects to Acme /oauth/authorize.
        resource :authorization, only: :show, path: ""

        resource :callback, only: :show

        # RP local logout: destroys only the local session.
        resource :logout, only: :create
      end

      # Signed-out landing page.
      namespace :signed, path: "" do
        resource :out, only: :show, path: "signed-out"
      end

      # OIDC back-channel receiver.
      scope module: :oidc, path: "oidc" do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

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
        # Sign-up ceremony.
        namespace :up do
          resource :email, only: %i(new create)
          resource :telephone, only: %i(new create)

          namespace :guard do
            resource :email, only: :show
            resource :telephone, only: :show
          end

          namespace :check do
            namespace :email do
              resource :otp, only: %i(show create update)
              resource :birthdate, only: %i(show update)
              resource :cancellation, only: :create
            end

            namespace :telephone do
              resource :otp, only: %i(show create update)
              resource :passkey, only: %i(show create update)
              resource :passcode, only: %i(show update)
              resource :birthdate, only: %i(show update)
              resource :cancellation, only: :create
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

          namespace :session do
            resource :cancellation, only: :create
          end

          resource :guard, only: :show
          resource :check, only: %i(show update)

          namespace :check do
            resource :cancellation, only: :create
          end

          resource :challenge, only: :show

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Step-up verification.
      resource :verification, only: :show
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

        namespace :mfa do
          resource :challenge, only: :show
        end

        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end

        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end

        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :secret_credentials, only: %i(index show new edit create update destroy) do
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
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Staff credential gateway host.
  constraints host: boot_config.fetch(:hosts).sign_staff.host do
    scope module: :org, as: :org do
      # Thin landing endpoint.
      root to: "roots#index"

      # Well-known public keys.
      namespace :well_known, path: ".well-known" do
        # JWKS endpoint; keep fixed JSON suffix.
        resource :jwks, only: :show, path: "jwks.json", format: false
      end

      # Dashboard.
      resource :dashboard, only: :show

      # Staff management areas.
      resource :configuration, only: :show
      resources :accounts, only: :index
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      resources :billing, only: :index

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

      # Canonical ceremony entrypoints.
      resource :sign_up, only: :show, path: "sign/up", controller: "sign/up"
      resource :sign_in, only: :show, path: "sign/in", controller: "sign/in"

      # Auth callback and RP login/logout endpoints.
      namespace :auth, path: "auth" do
        # RP login start: redirects to Acme /oauth/authorize.
        resource :authorization, only: :show, path: ""

        resource :callback, only: :show

        # RP local logout: destroys only the local session.
        resource :logout, only: :create
      end

      # Signed-out landing page.
      namespace :signed, path: "" do
        resource :out, only: :show, path: "signed-out"
      end

      # OIDC back-channel receiver.
      scope module: :oidc, path: "oidc" do
        namespace :backchannel do
          resource :logout, only: :create
        end
      end

      # CSP report sink; keep configured report-uri path.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

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
        # Staff invitation sign-up.
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

          namespace :session do
            resource :cancellation, only: :create
          end

          resource :guard, only: :show
          resource :check, only: %i(show update)

          namespace :check do
            resource :cancellation, only: :create
          end

          resource :challenge, only: :show

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Step-up verification.
      resource :verification, only: :show
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
          resource :verification, only: :create
        end

        namespace :mfa do
          resource :challenge, only: :show
        end

        resources :secret_credentials

        resources :sessions, only: %i(index show) do
          resource :revocation, only: :create
        end

        namespace :revocations do
          resource :others, only: :create
          resource :all, only: :create
        end

        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end

        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end

        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show
        resources :activities, only: :index
        resource :withdrawal, only: :show

        # Lifecycle request state transitions.
        resources :operator_lifecycle_requests, only: %i(index show new create) do
          scope module: :operator_lifecycle_requests do
            resource :approval, only: :create
            resource :execution, only: :create
            resource :rejection, only: :create
          end
        end
      end
    end
  end
end
