# Routes for sign-service app, com, and org domains grouped by auth, settings, API, OAuth/OIDC,
# and management features.

# typed: false
# frozen_string_literal: true

# TODO: remove these code!!!
safe_sign_state_redirect =
  lambda do |path|
    redirect(status: 307) do |_params, request|
      query = request.query_parameters.slice("ri", "pt", "sid")
      query.present? ? "#{path}?#{query.to_query}" : path
    end
  end

scope module: :sign, as: :sign do
  # User auth service (id.app domain)
  constraints host: ENV["SIGN_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false

      # Basic public endpoints
      resource :health, only: :show
      namespace :health do
        resource :live, only: :show
        resource :ready, only: :show
        resource :startup, only: :show
      end
      resource :robots, only: :show, path: "robots.txt"
      resource :sitemap, only: :show, path: "sitemap.xml"
      # FIXME: how about csp? csp_violation_report is so long naming.
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # FIXME: Remove this once we've migrated to the new welcome flow
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resources :welcomes, only: :show
      # FIXME: move to check entry point.
      resource :selector, only: :show
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

      # TODO: ckeck this code!
      namespace :r18 do
        resource :gate, only: %i(show create) do
          get :blocked
          get :stopped
        end
      end
      if Rails.env.local?
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        namespace :__dev, module: :dev, path: "__dev" do
          namespace :r18 do
            resource :open, only: %i(show create), controller: "open_smokes"
            resource :private, only: %i(show create), controller: "private_smokes"
          end
        end
      end

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end

      # Preferences
      resource :preference, only: [:show], controller: "preferences"
      namespace :preference do
        resource :region, only: %i(edit update), controller: "regions", defaults: { preference_screen: "region" }
        resource :timezone, only: %i(edit update), controller: "timezones", defaults: { preference_screen: "timezone" }
        resource :language, only: %i(edit update), controller: "languages", defaults: { preference_screen: "language" }
        resource :currency, only: %i(edit update), controller: "currencies", defaults: { preference_screen: "currency" }
        resource :date, only: %i(edit update), controller: "dates", defaults: { preference_screen: "date" }
        resource :time, only: %i(edit update), controller: "times", defaults: { preference_screen: "time" }
        resource :motion, only: %i(edit update), controller: "motions", defaults: { preference_screen: "motion" }
        resource :density, only: %i(edit update), controller: "densities", defaults: { preference_screen: "density" }
        resource :page_size, only: %i(edit update), controller: "page_sizes",
                             defaults: { preference_screen: "page_size" }
        resource :adult_content_gate, only: %i(edit update), controller: "adult_content_gates",
                                      defaults: { preference_screen: "adult_content_gate" }
        resource :theme, only: %i(edit update), controller: "themes", defaults: { preference_screen: "theme" }
        resource :cookie, only: %i(edit update), controller: "cookies", defaults: { preference_screen: "cookie" }
        resource :reset, only: %i(edit destroy)
        resources :emails, only: %i(edit destroy)
        post "emails/:id", to: "emails#create"
      end

      # FIXME: use resource and namespace
      # Sign-up and sign-in
      scope path: "sign" do
        # Sign-up: account registration via email or telephone
        resource :sign_up, path: "up", controller: "sign_ups", only: :new
        namespace :up do
          resource :email, only: %i(new create)
          resource :telephone, only: %i(new create)
          resource :guard, only: :show, controller: "guards"
          resource :check, only: %i(show destroy), controller: "checkpoints"

          namespace :guard do
            resource :apple, only: %i(show)
            resource :google, only: %i(show)
            resource :email, only: %i(show)
            resource :telephone, only: %i(show)
          end

          namespace :check do
            namespace :apple do
              resource :confirmation, only: %i(show update destroy)
              resource :birthdate, only: %i(show update destroy)
            end

            namespace :google do
              resource :confirmation, only: %i(show update destroy)
              resource :birthdate, only: %i(show update destroy)
            end

            namespace :email do
              resource :otp, only: %i(show create update destroy)
              resource :birthdate, only: %i(show update destroy)
            end

            namespace :telephone do
              resource :otp, only: %i(show create update destroy)
              resource :passkey, only: %i(show create update destroy)
              resource :passcode, only: %i(show update destroy)
              resource :birthdate, only: %i(show update destroy)
            end
          end
        end

        # FIXME: use resource and namespace
        # Sign-in: credential entry and session establishment
        resource :sign_in, path: "in", controller: "sign_ins", only: %i(new)
        namespace :in do
          resource :email, only: %i(new create edit update)
          resources :passkeys, only: [:new] do
            collection do
              post :options
              post :verification
            end
          end
          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)
          resource :guard, only: :show, controller: "guards"
          resource :check, only: %i(show update destroy), controller: "checkpoints"
          get "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          patch "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          delete "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          resource :challenge, only: %i(show)
          namespace :challenge do
            resource :totp, only: %i(new create)
            resource :passkey, only: %i(new create)
          end
        end
        resource :sign_out, path: "out", controller: "sign_outs", only: %i(show edit create destroy)
      end

      # Social auth: continue sets intent/state then redirects to /auth/:provider.
      namespace :social do
        resources :authentications,
                  path: "auth",
                  param: :provider,
                  only: [:destroy] do
          post :continue, on: :member
        end
      end

      # OmniAuth callbacks: Google uses GET; Apple may return GET or POST depending on response_mode.
      namespace :auth, path: "auth" do
        get ":provider/callback",
            to: "omniauth_callbacks#omniauth",
            constraints: { provider: /google_app/ },
            as: :callback

        match ":provider/callback",
              to: "omniauth_callbacks#omniauth",
              constraints: { provider: /apple/ },
              via: %i(get post),
              as: :apple_callback

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
          post :resend, on: :member
        end
      end

      # OIDC
      namespace :oidc do
        resource :logout, only: :show
      end

      # OAuth
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create
        resource :user_info, only: :show, path: "userinfo", controller: "user_info"
        resource :revocation, only: :create, path: "revoke", controller: "revocations"
        resource :jwks, only: :show
      end

      # MFA reset
      namespace :mfa, module: "settings/mfa" do
        resource :reset, only: %i(show create)
      end

      # Account settings and linked identity management
      resource :settings, only: :show
      namespace :settings do
        resources :totps, only: %i(index new create edit update destroy)
        resources :passkeys do
          collection do
            post :options
            post :verification
          end
        end
        # TODO: what is the following line? check it out!
        namespace :mfa do
          resource :challenge, only: %i(show)
        end
        resources :emails, only: %i(index edit update destroy)
        namespace :emails do
          resource :registration, only: %i(new create edit update) do
            # TODO: what is the following line? check it out!
            post :resend
          end
        end
        # FIXME: merge those two namespaces.
        resources :telephones, only: %i(new create edit)
        resources :telephones, only: %i(index destroy), controller: "telephones/redirects"
        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resource :birthdate, only: :show
        resource :apple, only: :show
        resource :google, only: :show
        # FIXME: rename this to "secrets"
        resource :emergency_key, only: :show
        resources :secret_credentials, only: %i(index show new edit create update destroy) do
          post :regenerate, on: :member
        end
        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end
        # FIXME: I did delete this entrypoint last month.
        resources :connections, only: %i(index show destroy), controller: "connections"
        resources :activities, only: :index, controller: "activities"
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Corporate id service (id.com domain)
  constraints host: ENV["SIGN_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false

      get :welcome, to: "welcomes#show", as: :welcome_entry
      resources :welcomes, only: :show
      resource :selector, only: :show
      resource :dashboard, only: :show

      # Basic public endpoints
      resource :health, only: :show
      namespace :health do
        resource :live, only: :show
        resource :ready, only: :show
        resource :startup, only: :show
      end
      resource :robots, only: :show, path: "robots.txt"
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

      namespace :r18 do
        resource :gate, only: %i(show create) do
          get :blocked
          get :stopped
        end
      end

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end

      # Preferences
      resource :preference, only: [:show], controller: "preferences"
      namespace :preference do
        resource :region, only: %i(edit update), controller: "regions", defaults: { preference_screen: "region" }
        resource :timezone, only: %i(edit update), controller: "timezones", defaults: { preference_screen: "timezone" }
        resource :language, only: %i(edit update), controller: "languages", defaults: { preference_screen: "language" }
        resource :currency, only: %i(edit update), controller: "currencies", defaults: { preference_screen: "currency" }
        resource :date, only: %i(edit update), controller: "dates", defaults: { preference_screen: "date" }
        resource :time, only: %i(edit update), controller: "times", defaults: { preference_screen: "time" }
        resource :motion, only: %i(edit update), controller: "motions", defaults: { preference_screen: "motion" }
        resource :density, only: %i(edit update), controller: "densities", defaults: { preference_screen: "density" }
        resource :page_size, only: %i(edit update), controller: "page_sizes",
                             defaults: { preference_screen: "page_size" }
        resource :adult_content_gate, only: %i(edit update), controller: "adult_content_gates",
                                      defaults: { preference_screen: "adult_content_gate" }
        resource :theme, only: %i(edit update), controller: "themes", defaults: { preference_screen: "theme" }
        resource :cookie, only: %i(edit update), controller: "cookies", defaults: { preference_screen: "cookie" }
        resources :emails, only: %i(edit destroy)
        post "emails/:id", to: "emails#create"
        resource :reset, only: %i(edit destroy)
      end

      # Sign-up and sign-in
      scope path: "sign" do
        # Sign-up: account registration via email or telephone
        resource :sign_up, path: "up", controller: "sign_ups", only: :new
        namespace :up do
          resource :email, only: %i(new create)
          resource :telephone, only: %i(new create)
          resource :guard, only: :show, controller: "guards"
          resource :check, only: %i(show destroy), controller: "checkpoints"

          namespace :guard do
            resource :email, only: %i(show)
            resource :telephone, only: %i(show)
          end

          namespace :check do
            namespace :email do
              resource :otp, only: %i(show create update destroy)
              resource :birthdate, only: %i(show update destroy)
            end

            namespace :telephone do
              resource :otp, only: %i(show create update destroy)
              resource :passkey, only: %i(show create update destroy)
              resource :passcode, only: %i(show update destroy)
              resource :birthdate, only: %i(show update destroy)
            end
          end
        end

        # Sign-in: credential entry and session establishment
        resource :sign_in, path: "in", controller: "sign_ins", only: %i(new)
        namespace :in do
          resource :email, only: %i(new create edit update)

          resources :passkeys, only: [:new] do
            collection do
              post :options
              post :verification
            end
          end

          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)
          resource :guard, only: :show, controller: "guards"
          resource :check, only: %i(show update destroy), controller: "checkpoints"
          get "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          patch "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          delete "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          resource :challenge, only: %i(show)

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end

        resource :sign_out, path: "out", controller: "sign_outs", only: %i(show edit create destroy)
      end

      # Step-up verification
      resource :verification, only: %i(show)
      namespace :verification do
        resource :setup, only: %i(new)
        resource :passkey, only: %i(new create)

        resources :emails, only: %i(new create edit update) do
          post :resend, on: :member
        end
      end

      # OIDC
      namespace :oidc do
        resource :logout, only: :show
      end

      # OAuth
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create
        resource :user_info, only: :show, path: "userinfo", controller: "user_info"
        resource :revocation, only: :create, path: "revoke", controller: "revocations"
        resource :jwks, only: :show
      end

      # Account settings and linked identity management
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          collection do
            post :options
            post :verification
          end
        end

        namespace :mfa do
          resource :challenge, only: %i(show)
        end

        resources :emails, only: %i(index edit update destroy)
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end

        resources :telephones, only: %i(new create edit)
        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index destroy), controller: "telephones/redirects"

        resource :birthdate, only: :show

        resources :secret_credentials, only: %i(index show new edit create update destroy) do
          post :regenerate, on: :member
        end

        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end

        resources :connections, only: %i(index show destroy), controller: "connections"
        resources :activities, only: :index, controller: "activities"
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Staff auth management
  constraints host: ENV["SIGN_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false

      get :welcome, to: "welcomes#show", as: :welcome_entry
      resources :welcomes, only: :show
      resource :selector, only: :show
      resource :dashboard, only: :show

      # Staff management top-level areas
      resources :accounts, only: :index
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      resources :billing, only: :index

      # Basic public endpoints
      resource :health, only: :show
      namespace :health do
        resource :live, only: :show
        resource :ready, only: :show
        resource :startup, only: :show
      end
      resource :robots, only: :show, path: "robots.txt"
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

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end

      # Preferences
      resource :preference, only: [:show], controller: "preferences"
      namespace :preference do
        resource :region, only: %i(edit update), controller: "regions", defaults: { preference_screen: "region" }
        resource :timezone, only: %i(edit update), controller: "timezones", defaults: { preference_screen: "timezone" }
        resource :language, only: %i(edit update), controller: "languages", defaults: { preference_screen: "language" }
        resource :currency, only: %i(edit update), controller: "currencies", defaults: { preference_screen: "currency" }
        resource :date, only: %i(edit update), controller: "dates", defaults: { preference_screen: "date" }
        resource :time, only: %i(edit update), controller: "times", defaults: { preference_screen: "time" }

        resource :motion, only: %i(edit update), controller: "motions", defaults: { preference_screen: "motion" }
        resource :density, only: %i(edit update), controller: "densities", defaults: { preference_screen: "density" }

        resource :page_size, only: %i(edit update), controller: "page_sizes",
                             defaults: { preference_screen: "page_size" }
        resource :adult_content_gate, only: %i(edit update), controller: "adult_content_gates",
                                      defaults: { preference_screen: "adult_content_gate" }

        resource :theme, only: %i(edit update), controller: "themes", defaults: { preference_screen: "theme" }
        resource :cookie, only: %i(edit update), controller: "cookies", defaults: { preference_screen: "cookie" }

        resources :emails, only: %i(edit destroy)
        post "emails/:id", to: "emails#create"

        resource :reset, only: %i(edit destroy)
      end

      # Sign-up: email registration and staff invitation flows
      scope path: "sign" do
        resource :sign_up, path: "up", controller: "sign_ups", only: :new
        namespace :up do
          resources :invitations, only: %i(new create)
        end
      end

      # Sign-in: credential entry and session establishment
      scope path: "sign" do
        resource :sign_in, path: "in", controller: "sign_ins", only: [:new]
        namespace :in do
          resources :passkeys, only: [:new] do
            collection do
              post :options
              post :verification
            end
          end

          resource :secret_credential, only: %i(new create)
          resource :session, only: %i(show update destroy)
          resource :guard, only: :show, controller: "guards"
          resource :check, only: %i(show update destroy), controller: "checkpoints"
          get "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          patch "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          delete "checkpoint", to: safe_sign_state_redirect.call("/sign/in/check"), as: nil
          resource :challenge, only: %i(show)

          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end

        resource :sign_out, path: "out", controller: "sign_outs", only: %i(show edit create destroy)
      end

      # Step-up verification
      resource :verification, only: %i(show)
      namespace :verification do
        resource :setup, only: %i(new)
        resource :passkey, only: %i(new create)
      end

      # OIDC
      namespace :oidc do
        resource :logout, only: :show
      end

      # OAuth
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create
        resource :user_info, only: :show, path: "userinfo", controller: "user_info"
        resource :revocation, only: :create, path: "revoke", controller: "revocations"
        resource :jwks, only: :show
      end

      # Account settings and identity management
      resource :settings, only: :show
      namespace :settings do
        resources :passkeys do
          collection do
            post :options
            post :verification
          end
        end

        namespace :mfa do
          resource :challenge, only: %i(show)
        end

        resources :secret_credentials

        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end

        resources :connections, only: %i(index show destroy), controller: "connections"

        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)

        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(new create edit)
        resources :telephones, only: %i(index destroy), controller: "telephones/redirects"

        resource :birthdate, only: :show
        resources :activities, only: :index, controller: "activities"
        resource :withdrawal, only: %i(show)

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
