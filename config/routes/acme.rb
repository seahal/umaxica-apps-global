# typed: false
# frozen_string_literal: true

scope module: :acme, as: :acme do
  acme_app_hosts = [ENV["ACME_SERVICE_URL"], "app.localhost", "www.app.localhost"].compact.uniq
  acme_com_hosts = [ENV["ACME_CORPORATE_URL"], "com.localhost", "www.com.localhost"].compact.uniq
  acme_org_hosts = [ENV["ACME_STAFF_URL"], "org.localhost", "www.org.localhost"].compact.uniq

  constraints host: acme_app_hosts do
    scope module: :app, as: :app do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # TODO: I think following two lines of routing are same meaing.
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resources :welcomes, only: :show
      resource :dashboard, only: :show
      resource :verification, only: :show do
        post :completion
      end
      resource :preference, only: [:show]
      namespace :preference do
        resource :region, only: %i(edit update), controller: "screens", defaults: { preference_screen: "region" }
        resource :timezone, only: %i(edit update), controller: "screens", defaults: { preference_screen: "timezone" }
        resource :language, only: %i(edit update), controller: "screens", defaults: { preference_screen: "language" }
        resource :currency, only: %i(edit update), controller: "screens", defaults: { preference_screen: "currency" }
        resource :date, only: %i(edit update), controller: "screens", defaults: { preference_screen: "date" }
        resource :time, only: %i(edit update), controller: "screens", defaults: { preference_screen: "time" }
        resource :motion, only: %i(edit update), controller: "screens", defaults: { preference_screen: "motion" }
        resource :density, only: %i(edit update), controller: "screens", defaults: { preference_screen: "density" }
        resource :page_size, only: %i(edit update), controller: "screens", defaults: { preference_screen: "page_size" }
        resource :adult_content_gate, only: %i(edit update), controller: "screens",
                                      defaults: { preference_screen: "adult_content_gate" }
        resource :theme, only: %i(edit update), controller: "screens", defaults: { preference_screen: "theme" }
        resource :cookie, only: %i(edit update), controller: "screens", defaults: { preference_screen: "cookie" }
        resource :reset, only: %i(edit destroy)
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
          resource :health, only: :show
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
                  path: "auth",
                  param: :provider do
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

  constraints host: acme_com_hosts do
    scope module: :com, as: :com do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resources :welcomes, only: :show
      resource :dashboard, only: :show
      resource :verification, only: :show do
        post :completion
      end
      resource :preference, only: [:show]
      namespace :preference do
        resource :region, only: %i(edit update), controller: "screens", defaults: { preference_screen: "region" }
        resource :timezone, only: %i(edit update), controller: "screens", defaults: { preference_screen: "timezone" }
        resource :language, only: %i(edit update), controller: "screens", defaults: { preference_screen: "language" }
        resource :currency, only: %i(edit update), controller: "screens", defaults: { preference_screen: "currency" }
        resource :date, only: %i(edit update), controller: "screens", defaults: { preference_screen: "date" }
        resource :time, only: %i(edit update), controller: "screens", defaults: { preference_screen: "time" }
        resource :motion, only: %i(edit update), controller: "screens", defaults: { preference_screen: "motion" }
        resource :density, only: %i(edit update), controller: "screens", defaults: { preference_screen: "density" }
        resource :page_size, only: %i(edit update), controller: "screens", defaults: { preference_screen: "page_size" }
        resource :adult_content_gate, only: %i(edit update), controller: "screens",
                                      defaults: { preference_screen: "adult_content_gate" }
        resource :theme, only: %i(edit update), controller: "screens", defaults: { preference_screen: "theme" }
        resource :cookie, only: %i(edit update), controller: "screens", defaults: { preference_screen: "cookie" }
        resource :reset, only: %i(edit destroy)
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
          resource :health, only: :show
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

  constraints host: acme_org_hosts do
    scope module: :org, as: :org do
      root to: "roots#index"
      resource :jwks, only: :show, path: ".well-known/jwks.json", format: false
      resource :openid_configuration,
               only: :show,
               path: ".well-known/openid-configuration",
               controller: "openid_configurations",
               format: false
      # Health
      resource :health, only: :show
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      get :welcome, to: "welcomes#show", as: :welcome_entry
      resources :welcomes, only: :show
      resource :dashboard, only: :show
      resource :verification, only: :show do
        post :completion
      end
      resource :preference, only: [:show]
      namespace :preference do
        resource :region, only: %i(edit update), controller: "screens", defaults: { preference_screen: "region" }
        resource :timezone, only: %i(edit update), controller: "screens", defaults: { preference_screen: "timezone" }
        resource :language, only: %i(edit update), controller: "screens", defaults: { preference_screen: "language" }
        resource :currency, only: %i(edit update), controller: "screens", defaults: { preference_screen: "currency" }
        resource :date, only: %i(edit update), controller: "screens", defaults: { preference_screen: "date" }
        resource :time, only: %i(edit update), controller: "screens", defaults: { preference_screen: "time" }
        resource :motion, only: %i(edit update), controller: "screens", defaults: { preference_screen: "motion" }
        resource :density, only: %i(edit update), controller: "screens", defaults: { preference_screen: "density" }
        resource :page_size, only: %i(edit update), controller: "screens", defaults: { preference_screen: "page_size" }
        resource :adult_content_gate, only: %i(edit update), controller: "screens",
                                      defaults: { preference_screen: "adult_content_gate" }
        resource :theme, only: %i(edit update), controller: "screens", defaults: { preference_screen: "theme" }
        resource :cookie, only: %i(edit update), controller: "screens", defaults: { preference_screen: "cookie" }
        resource :reset, only: %i(edit destroy)
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
          resource :health, only: :show
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
      root to: "roots#index", as: :root
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: ENV["ACME_DEVELOPER_URL"] do
    scope module: :dev, as: :developer do
      root to: "roots#index", as: :root
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # to show the jobs page
      mount MissionControl::Jobs::Engine, at: "/jobs"
      # to show the rails db page
      mount RailsDb::Engine, at: "/db"
    end
  end
end
