# typed: false
# frozen_string_literal: true

scope module: :acme, as: :acme do
  # Primary application surface
  constraints host: [ENV["ACME_SERVICE_URL"], "app.localhost", "www.app.localhost"].compact do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false
      # Health
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      # Robots
      resource :robot, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resource :dashboard, only: :show
      resource :selector, only: %i(show update)
      resource :verification, only: :show do
        post :completion
      end
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
      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API
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
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :social do
        resources :authentications,
                  only: [],
                  path: "auth" do
          post :continue, on: :member
          post :completion, on: :member
        end
      end
      if Rails.env.local?
        # TODO: Remove these temporary R18 smoke-test routes after R18 gate rollout is verified.
        namespace :__dev, module: :dev, path: "__dev" do
          namespace :r18 do
            resource :gate, only: %i(show create) do
              get :blocked
              get :stopped
            end
            resource :open, only: %i(show create), controller: "open_smokes"
            resource :private, only: %i(show create), controller: "private_smokes"
          end
        end
      end
      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end
      namespace :oidc do
        resource :logout, only: :show
      end
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create
        resource :user_info, only: :show, path: "userinfo", controller: "user_info"
        resource :revocation, only: :create, path: "revoke", controller: "revocations"
        resource :jwks, only: :show
      end
      scope path: "sign" do
        resource :sign_out, path: "out", controller: "sign_outs", only: %i(show edit create destroy)
      end
      resource :avatar, only: :show
      resource :identity, only: :show
      resource :organization, only: :show
      resource :account, only: :show, controller: "accounts"
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
          # FIXME: Check these entrypoints are still needed.
          collection do
            delete :others
            delete :revoke_all
          end
        end
        resource :withdrawal, only: %i(new update create edit destroy)
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  # Corporate surface
  constraints host: [ENV["ACME_CORPORATE_URL"], "com.localhost", "www.com.localhost"].compact do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false
      # Health
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      # Robots
      resource :robot, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resource :selector, only: %i(show update)
      resource :dashboard, only: :show
      resource :verification, only: :show do
        post :completion
      end
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
      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API
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
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end
      namespace :oidc do
        resource :logout, only: :show
      end
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create
        resource :user_info, only: :show, path: "userinfo", controller: "user_info"
        resource :revocation, only: :create, path: "revoke", controller: "revocations"
        resource :jwks, only: :show
      end
      scope path: "sign" do
        resource :sign_out, path: "out", controller: "sign_outs", only: %i(show edit create destroy)
      end
      resource :identity, only: :show
      resource :account, only: :show, controller: "accounts"
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
      # for account page
      resources :accounts, only: [:index]
    end
  end

  # Staff surface
  constraints host: [ENV["ACME_STAFF_URL"], "org.localhost", "www.org.localhost"].compact do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false
      # Health
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      # Robots
      resource :robot, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resource :selector, only: %i(show update)
      resource :dashboard, only: :show
      resource :configuration, only: :show
      resources :iam, only: :index
      resources :system, only: :index
      resources :audit, only: :index
      resources :support, only: :index
      resources :billing, only: :index
      resource :verification, only: :show do
        post :completion
      end
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
      # Public web API: cookie consent, theme
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API
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
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :sso do
        resource :authorization, only: :show, path: "authorize"
        resource :logout, only: :create
      end
      namespace :oidc do
        resource :logout, only: :show
      end
      namespace :oauth do
        resource :authorization, only: :show, path: "authorize"
        resource :token, only: :create
        resource :user_info, only: :show, path: "userinfo", controller: "user_info"
        resource :revocation, only: :create, path: "revoke", controller: "revocations"
        resource :jwks, only: :show
      end
      scope path: "sign" do
        resource :sign_out, path: "out", controller: "sign_outs", only: %i(show edit create destroy)
      end
      resource :avatar, only: :show
      resource :identity, only: :show
      resource :organization, only: :show
      resource :account, only: :show, controller: "accounts"
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
        resource :withdrawal, only: %i(show)
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  constraints host: ENV["ACME_NETWORK_URL"] do
    scope module: :net, as: :network do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: ENV["ACME_DEVELOPER_URL"] do
    scope module: :dev, as: :developer do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      namespace :health do
        resource :liveness, only: :show
        resource :readiness, only: :show
        resource :startup, only: :show
      end
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # to show the jobs page
      mount MissionControl::Jobs::Engine, at: "/jobs"
      # to show the rails db page
      mount RailsDb::Engine, at: "/db"
    end
  end
end
