# typed: false
# frozen_string_literal: true

# Sign owns the credential gateway surfaces. Acme is the sole IdP /
# Authorization Server; every Sign surface is an OIDC relying party.
#
# Route mapper macros (sign_routes/sign_surface/sign_public_gateway_routes/
# sign_rp_oidc_routes/sign_app_social_routes) live in
# config/initializers/sign_route_mapper.rb. Protocol/public fixed paths and
# the social `to:`/`defaults:` wiring are isolated there so the surface
# groups below read as a contract table.
sign_routes do
  hosts = Rails.configuration.x.boot_config.fetch(:hosts)

  # User credential gateway host.
  sign_surface :app, host: [hosts.sign_service.host, "sign.app.localhost"] do
    root "roots#index"

    sign_public_gateway_routes

    # Canonical ceremony entrypoints and signed-out confirmation/cleanup.
    namespace :sign do
      resource :up, only: :show
      resource :in, only: :show
      resource :out, only: %i(new edit create) do
        get :complete, on: :collection
      end
    end

    sign_rp_oidc_routes

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
            resource :confirmation, only: %i(show update destroy)
            resource :birthdate, only: %i(show update)
            resource :cancellation, only: :create # FIXME: use delete method!
          end

          namespace :google do
            resource :confirmation, only: %i(show update destroy)
            resource :birthdate, only: %i(show update)
            resource :cancellation, only: :create # FIXME: use delete method!
          end

          namespace :email do
            resource :otp, only: %i(show create update)
            resource :birthdate, only: %i(show update)
            resource :cancellation, only: :create # FIXME: use delete method!
          end

          namespace :telephone do
            resource :otp, only: %i(show create update)
            resource :passkey, only: %i(show create update)
            resource :passcode, only: %i(show update)
            resource :birthdate, only: %i(show update)
            resource :cancellation, only: :create # FIXME: use delete method!
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

    sign_app_social_routes

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
      resource :apple, only: %i(show edit create destroy)
      resource :google, only: %i(show edit create destroy)
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

  # Corporate credential gateway host.
  sign_surface :com, host: [hosts.sign_corporate.host, "sign.com.localhost"] do
    root "roots#index"

    sign_public_gateway_routes

    # Canonical ceremony entrypoints and signed-out confirmation.
    namespace :sign do
      resource :up, only: :show
      resource :in, only: :show
      resource :out, only: %i(new edit create) do
        get :complete, on: :collection
      end
    end

    sign_rp_oidc_routes

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
        resource :email, only: %i(new create edit)

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

      resource :secrets, only: :show

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

  # Staff credential gateway host.
  sign_surface :org, host: [hosts.sign_staff.host, "sign.org.localhost"] do
    root "roots#index"

    sign_public_gateway_routes

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

    # Canonical ceremony entrypoints and signed-out confirmation.
    namespace :sign do
      resource :up, only: :show
      resource :in, only: :show
      resource :out, only: %i(new edit create) do
        get :complete, on: :collection
      end
    end

    sign_rp_oidc_routes

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
        resource :verification, only: :create # TODO: check this statement!
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
