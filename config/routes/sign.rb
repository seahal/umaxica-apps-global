# Routes for sign-service app, com, and org domains grouped by auth, settings, API, OAuth/OIDC,
# and management features.

# typed: false
# frozen_string_literal: true

scope module: :sign, as: :sign do
  # User auth service (id.app domain)
  constraints host: ENV["SIGN_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      # Basic public endpoints
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robot, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # for those who are logged in
      resource :dashboard, only: :show
      # Public web API: OTP delivery, cookie consent, theme
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

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
          end
        end
      end

      # Sign: sign-up, sign-in, and sign-out lifecycle routes.
      namespace :sign do
        # Sign-up: account registration via email or telephone
        namespace :up do
          resource :entrance, only: :show
          resource :email, only: %i(new create)
          resource :telephone, only: %i(new create)

          namespace :guard do
            resource :apple, only: %i(show)
            resource :google, only: %i(show)
            resource :email, only: %i(show)
            resource :telephone, only: %i(show)
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

        # Sign-in: credential entry and session establishment
        namespace :in do
          resource :entrance, only: :show
          resource :email, only: %i(new create edit update)
          resource :passkey, only: :new
          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end
          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)
          # FIXME: I want to rename this much smarter naming.
          resource :session_cancellation, only: :create
          resource :guard, only: :show
          resource :check, only: %i(show update)
          resource :check_cancellation, only: :create
          resource :challenge, only: %i(show)
          namespace :challenge do
            resource :totp, only: %i(new create)
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Social auth: settings-side social connection lifecycle.
      namespace :social do
        namespace :apple do
          resource :connection, only: :show
          # FIXME: I want to rename this much smarter naming.
          resource :connection_attempt, only: :create
          # FIXME: I want to rename this much smarter naming.
          resource :disconnection_attempt, only: :create
        end

        namespace :google do
          resource :connection, only: :show
          # FIXME: I want to rename this much smarter naming.
          resource :connection_attempt, only: :create
          # FIXME: I want to rename this much smarter naming.
          resource :disconnection_attempt, only: :create
        end
      end

      # OmniAuth callbacks: Google uses GET; Apple may return GET or POST depending on response_mode.
      namespace :auth, path: "auth" do
        resource :callback, only: :show
        get "google_app/callback",
            to: "omniauth_callbacks#omniauth",
            as: :google_app_callback,
            defaults: { provider: "google_app" }
        match "apple/callback",
              to: "omniauth_callbacks#omniauth",
              via: %i(get post),
              as: :apple_callback,
              defaults: { provider: "apple" }

        get "failure",
            to: "omniauth_callbacks#failure"
      end

      # Step-up verification
      resource :verification, only: %i(show)
      namespace :verification do
        # TODO: what is the following line? check it out!
        resource :setup, only: %i(new)
        resource :passkey, only: %i(new create)
        resource :totp, only: %i(new create)
        resources :emails, only: %i(new create edit update) do
          # FIXME: I want to rename this much smarter naming.
          resource :redelivery, only: :create
        end
      end

      # Account settings and linked identity management
      resource :settings, only: :show
      namespace :settings do
        namespace :mfa do
          resource :reset, only: %i(show create)
          resource :challenge, only: %i(show)
        end
        resources :totps, only: %i(index new create edit update destroy)
        resources :passkeys do
          # FIXME: I want to rename this much smarter naming.
          resource :removal_attempt, only: :create
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
        # FIXME: I want to rename this much smarter naming.
        scope path: "telephones", module: :telephones, as: :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new create edit destroy)
        resource :birthdate, only: :show
        resource :apple, only: :show
        resource :google, only: :show
        # FIXME: rename this to "secrets"
        resource :emergency_key, only: :show
        resources :secret_credentials, only: %i(index show new edit create update destroy) do
          # FIXME: I want to rename this much smarter naming.
          resource :rotation_attempt, only: :create
          # FIXME: I want to rename this much smarter naming.
          resource :removal_attempt, only: :create
        end
        resources :sessions, only: %i(index show) do
          # FIXME: I want to rename this much smarter naming.
          resource :revocation_attempt, only: :create
        end
        namespace :session_revocations do
          resource :others, only: :create
          resource :all, only: :create
        end
        resources :activities, only: :index
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Corporate id service (id.com domain)
  constraints host: ENV["SIGN_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :dashboard, only: :show

      # Basic public endpoints
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robot, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public web API: OTP delivery, cookie consent, theme
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

      # FIXME: REMOVE THIS!!!
      namespace :r18 do
        resource :gate, only: %i(show create) do
          get :blocked
          get :stopped
        end
      end

      namespace :auth, path: "auth" do
        resource :callback, only: :show
      end

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up and sign-in
      namespace :sign do
        # Sign-up: account registration via email or telephone
        namespace :up do
          resource :entrance, only: :show
          resource :email, only: %i(new create)
          resource :telephone, only: %i(new create)

          namespace :guard do
            resource :email, only: %i(show)
            resource :telephone, only: %i(show)
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

        # Sign-in: credential entry and session establishment
        namespace :in do
          resource :entrance, only: :show
          resource :email, only: %i(new create edit update)

          resource :passkey, only: :new
          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end
          # FIXME: I want to rename this much smarter naming.
          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)
          # FIXME: I want to rename this much smarter naming.
          resource :session_cancellation, only: :create
          resource :guard, only: :show
          resource :check, only: %i(show update)
          # FIXME: I want to rename this much smarter naming.
          resource :check_cancellation, only: :create
          resource :challenge, only: %i(show)

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Step-up verification
      resource :verification, only: %i(show)
      namespace :verification do
        resource :setup, only: %i(new)
        resource :passkey, only: %i(new create)

        resources :emails, only: %i(new create edit update) do
          resource :redelivery, only: :create
        end
      end

      # Account settings and linked identity management
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          # FIXME: I want to rename this much smarter naming.
          resource :removal_attempt, only: :create
        end
        namespace :passkeys do
          resource :options, only: :create
          resource :verification, only: :create
        end

        namespace :mfa do
          resource :challenge, only: %i(show)
        end

        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)

        # FIXME: I want to rename this much smarter naming.
        scope path: "telephones", module: :telephones, as: :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show

        resources :secret_credentials, only: %i(index show new edit create update destroy) do
          # FIXME: I want to rename this much smarter naming.
          resource :rotation_attempt, only: :create
          # FIXME: I want to rename this much smarter naming.
          resource :removal_attempt, only: :create
        end

        resources :sessions, only: %i(index show) do
          # FIXME: I want to rename this much smarter naming.
          resource :revocation_attempt, only: :create
        end
        # FIXME: I want to rename this much smarter naming.
        namespace :session_revocations do
          resource :others, only: :create
          resource :all, only: :create
        end

        resources :activities, only: :index
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Staff auth management
  constraints host: ENV["SIGN_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :dashboard, only: :show

      # Staff management top-level areas
      resource :configuration, only: :show
      resources :accounts, only: :index
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      resources :billing, only: :index

      # Basic public endpoints
      resource :health, only: :show
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      resource :robot, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      namespace :r18 do
        resource :gate, only: %i(show create) do
          get :blocked
          get :stopped
        end
      end

      namespace :auth, path: "auth" do
        resource :callback, only: :show
      end

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
          end
        end
      end

      # Sign-up: email registration and staff invitation flows
      namespace :sign do
        namespace :up do
          resource :entrance, only: :show
          resources :invitations, only: %i(new create)
        end

        # Sign-in: credential entry and session establishment
        namespace :in do
          resource :entrance, only: :show
          resource :passkey, only: :new
          namespace :passkey do
            resource :options, only: :create
            resource :verification, only: :create
          end
          # FIXME: I want to rename this much smarter naming.
          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)
          # FIXME: I want to rename this much smarter naming.
          resource :session_cancellation, only: :create
          resource :guard, only: :show
          resource :check, only: %i(show update)
          # FIXME: I want to rename this much smarter naming.
          resource :check_cancellation, only: :create
          resource :challenge, only: %i(show)

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
      end

      # Step-up verification
      resource :verification, only: %i(show)
      namespace :verification do
        resource :setup, only: %i(new)
        resource :passkey, only: %i(new create)
      end

      # TODO: move settings to acme's identity entrypoints.
      # Account settings and identity management
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          # FIXME: I want to rename this much smarter naming.
          resource :removal_attempt, only: :create
        end
        namespace :passkeys do
          resource :options, only: :create
          resource :verification, only: :create
        end

        namespace :mfa do
          resource :challenge, only: %i(show)
        end

        resources :secret_credentials

        resources :sessions, only: %i(index show) do
          # FIXME: I want to rename this much smarter naming.
          resource :revocation_attempt, only: :create
        end
        namespace :session_revocations do
          resource :others, only: :create
          resource :all, only: :create
        end
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)

        # FIXME: I want to rename this much smarter naming.
        scope path: "telephones", module: :telephones, as: :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new create edit destroy)

        resource :birthdate, only: :show
        resources :activities, only: :index
        resource :withdrawal, only: %i(show)

        # Lifecycle request state transitions.
        resources :operator_lifecycle_requests, only: %i(index show new create) do
          scope module: :operator_lifecycle_requests do
            resource :approval, only: %i(create)
            resource :execution, only: %i(create)
            resource :rejection, only: %i(create)
          end
        end
      end
    end
  end
end
