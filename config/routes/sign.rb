# typed: false
# frozen_string_literal: true

concern :social_auth_continue_routes do
  namespace :social do
    resources :authentications,
              path: "auth",
              param: :provider,
              only: [:destroy] do
      post :continue, on: :member
    end
  end
end

scope module: :sign, as: :sign do
  # User auth service (id.app domain)
  constraints host: ENV["SIGN_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :dashboard, only: :show
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # Public web API: OTP delivery, cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :health, only: :show
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
          resource :health, only: :show
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end
      # preferences
      resource :preference, only: [:show]
      namespace :preference do
        # for region settings.
        resource :region, only: [:edit, :update]
        namespace :region do
          # for lx and tz settings.
          resource :timezone, only: [:edit, :update]
          resource :language, only: [:edit, :update]
          resource :currency, only: [:edit, :update]
          resource :date_format, only: [:edit, :update] # FIXME: rename date_format to date
          resource :time_format, only: [:edit, :update] # FIXME: rename time_format to time
        end
        namespace :accessibility do
          resource :motion, only: [:edit, :update]
        end
        namespace :display do
          resource :density, only: [:edit, :update] # FIXME: move to accessibility namespace.
          resource :items_per_page, only: [:edit, :update]
        end
        # for dark/light mode
        resource :theme, only: [:edit, :update]
        # for ePrivacy settings.
        resource :cookie, only: [:edit, :update]
        # for non-sign-in-only email preferences.
        resources :email, only: %i(edit destroy)
        post "email/:id", to: "emails#create"
        # endpoint of reset preferences.
        resource :reset, only: [:edit, :destroy]
      end
      # Sign-up: account registration via email or telephone
      scope path: "sign" do
        resource :up, only: :new
        namespace :up do
          resource :email, only: %i(new create edit update)
          resource :guardrail, only: :show
          resource :checkpoint, only: %i(show update)
          resource :telephone, only: %i(new create edit update) do
            post :resend
            resource :passkey_registration, only: %i(show create) do
              post :begin, on: :member
            end
          end
        end
        # Sign-in: credential entry and session establishment
        resource :in, only: %i(new)
        namespace :in do
          resource :email, only: %i(new create edit update)
          resources :passkeys, only: [:new] do
            collection do
              post :options
              post :verification
            end
          end
          resource :secret, only: %i(new create)
          resource :session, only: %i(show update destroy)
          resource :checkpoint, only: %i(show update destroy)
          resource :challenge, only: %i(show)
          namespace :challenge do
            resource :totp, only: %i(new create)
            resource :passkey, only: %i(new create)
          end
        end
        # Sign-out: end only the current browser session.
        get "out", to: "out_notices#show", as: :signed_out
        resource :out, only: %i(edit create destroy)
      end
      # Social auth: continue sets intent/state then redirects to /auth/:provider.
      concerns :social_auth_continue_routes
      # OmniAuth callbacks: Google uses GET, Apple uses POST.
      namespace :auth, path: "auth" do
        get ":provider/callback",
            to: "omniauth_callbacks#omniauth",
            constraints: { provider: /google_app/ },
            as: :callback
        post ":provider/callback",
             to: "omniauth_callbacks#omniauth",
             constraints: { provider: /apple/ },
             as: :apple_callback
        get "failure",
            to: "omniauth_callbacks#failure"
      end
      # Step-up verification
      resource :verification, only: %i(show)
      namespace :verification do
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
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create, defaults: { format: :json }
        resource :jwks, only: :show, defaults: { format: :json }
      end
      get "sign/up", to: "sign_ups#show", as: :sign_up
      namespace :mfa, module: "configuration/mfa" do
        resource :reset, only: %i(show create)
      end
      # Account settings and linked identity management
      resource :configuration, only: %i(show edit)
      namespace :configuration do
        resources :totps, only: %i(index new create edit update destroy)
        resources :passkeys do
          collection do
            post :options
            post :verification
          end
        end
        namespace :mfa do
          resource :challenge, only: %i(show update)
        end
        namespace :emails do
          resource :registration, only: %i(new create edit update) do
            post :resend
          end
        end
        resources :emails, only: %i(index edit update destroy)
        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new edit create destroy)
        resource :birthdate, only: :show
        resource :apple, only: :show
        resource :google, only: %i(show create)
        resources :secrets, only: %i(index show new edit create destroy) do
          post :regenerate, on: :member
        end
        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end
        resources :connections, only: %i(index show destroy)
        resources :activities, only: :index
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Corporate id service (id.com domain)
  constraints host: ENV["SIGN_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :dashboard, only: :show
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
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

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end

      # preferences
      resource :preference, only: [:show]
      namespace :preference do
        # for region settings.
        resource :region, only: [:edit, :update]
        namespace :region do
          # for lx and tz settings.
          resource :timezone, only: [:edit, :update]
          resource :language, only: [:edit, :update]
          resource :currency, only: [:edit, :update]
          resource :date_format, only: [:edit, :update]
          resource :time_format, only: [:edit, :update]
        end
        namespace :accessibility do
          resource :motion, only: [:edit, :update]
        end
        namespace :display do
          resource :density, only: [:edit, :update]
          resource :items_per_page, only: [:edit, :update]
        end
        # for dark/light mode
        resource :theme, only: [:edit, :update]
        resources :email, only: %i(edit destroy)
        post "email/:id", to: "emails#create"
        resource :cookie, only: [:edit, :update]
        # endpoint of reset preferences.
        resource :reset, only: [:edit, :destroy]
      end

      # Sign-up: account registration via email or telephone
      scope path: "sign" do
        resource :up, only: :new
        namespace :up do
          resource :email, only: %i(new create edit update)
          resource :guardrail, only: :show
          resource :checkpoint, only: %i(show update)
          resource :telephone, only: %i(new create edit update)
        end

        # Sign-in: credential entry and session establishment
        resource :in, only: %i(new)
        namespace :in do
          resource :email, only: %i(new create edit update)
          resources :passkeys, only: [:new] do
            collection do
              post :options
              post :verification
            end
          end
          resource :secret, only: %i(new create)
          resource :session, only: %i(show update destroy)
          resource :checkpoint, only: %i(show update destroy)
          resource :challenge, only: %i(show)
          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
        get "out", to: "out_notices#show", as: :signed_out
        resource :out, only: %i(edit create destroy)
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

      namespace :oidc do
        resource :logout, only: :show
      end
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create, defaults: { format: :json }
        resource :jwks, only: :show, defaults: { format: :json }
      end
      get "sign/up", to: "sign_ups#show", as: :sign_up

      # Account settings and linked identity management
      resource :configuration, only: %i(show edit)
      namespace :configuration do
        resources :passkeys do
          collection do
            post :options
            post :verification
          end
        end
        resource :challenge, path: "mfa/challenge", only: %i(show update)
        resources :emails, only: %i(index edit update destroy)
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new edit create destroy)
        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resource :birthdate, only: :show
        resources :secrets, only: %i(index show new edit create destroy) do
          post :regenerate, on: :member
        end
        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end
        resources :connections, only: %i(index show destroy)
        resources :activities, only: :index
        resource :withdrawal, only: %i(new update create edit destroy)
      end
    end
  end

  # Staff auth management
  constraints host: ENV["SIGN_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :dashboard, only: :show
      resources :accounts, only: :index
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      resources :billing, only: :index
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"

      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end

      # Edge API: token lifecycle management (check, DBSC binding, refresh)
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          namespace :token do
            resource :check, only: :show
            resource :dbsc, only: :create
            resource :refresh, only: :create
          end
        end
      end
      # preferences
      resource :preference, only: [:show]
      namespace :preference do
        # for region settings.
        resource :region, only: [:edit, :update]
        namespace :region do
          # for lx and tz settings.
          resource :timezone, only: [:edit, :update]
          resource :language, only: [:edit, :update]
          resource :currency, only: [:edit, :update]
          resource :date_format, only: [:edit, :update]
          resource :time_format, only: [:edit, :update]
        end
        namespace :accessibility do
          resource :motion, only: [:edit, :update]
        end
        namespace :display do
          resource :density, only: [:edit, :update]
          resource :items_per_page, only: [:edit, :update]
        end
        # for dark/light mode
        resource :theme, only: [:edit, :update]
        resources :email, only: %i(edit destroy)
        post "email/:id", to: "emails#create"
        # endpoint of reset preferences.
        resource :reset, only: [:edit, :destroy]
        # for ePrivacy settings.
        resource :cookie, only: [:edit, :update]
      end

      # Sign-up: email registration and staff invitation flows
      scope path: "sign" do
        resource :up, only: :new
        namespace :up do
          resources :invitations, only: %i(new create)
        end
      end

      # Social auth: Google continue for staff. Unknown staff are not created.
      concerns :social_auth_continue_routes
      # OmniAuth callbacks: Google uses GET.
      namespace :auth, path: "auth" do
        get ":provider/callback",
            to: "omniauth_callbacks#omniauth",
            constraints: { provider: /google_org/ },
            as: :callback
        get "failure",
            to: "omniauth_callbacks#failure"
      end

      # Sign-in: credential entry and session establishment
      scope path: "sign" do
        resource :in, only: [:new]
        namespace :in do
          resources :passkeys, only: [:new] do
            collection do
              post :options
              post :verification
            end
          end
          resource :secret, only: %i(new create)
          resource :session, only: %i(show update destroy)
          resource :checkpoint, only: %i(show update destroy)
          resource :challenge, only: %i(show)
          namespace :challenge do
            resource :passkey, only: %i(new create)
          end
        end
        get "out", to: "out_notices#show", as: :signed_out
        resource :out, only: %i(edit create destroy)
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
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create, defaults: { format: :json }
        resource :jwks, only: :show, defaults: { format: :json }
      end
      get "sign/up", to: "sign_ups#show", as: :sign_up

      # Account settings and identity management
      resource :configuration, only: :show
      namespace :configuration do
        resources :passkeys do
          collection do
            post :options
            post :verification
          end
        end
        resource :challenge, path: "mfa/challenge", only: %i(show update)
        resources :secrets
        resources :sessions, only: %i(index destroy) do
          collection do
            delete :others
            delete :revoke_all
          end
        end
        resources :connections, only: %i(index show destroy)
        namespace :emails do
          resource :registration, only: %i(new create edit update)
        end
        resources :emails, only: %i(index edit update destroy)
        namespace :telephones do
          resource :registration, only: %i(new create edit update)
        end
        resources :telephones, only: %i(index new edit create destroy)
        resource :birthdate, only: :show
        resource :google, only: %i(show create)
        resources :activities, only: :index
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
