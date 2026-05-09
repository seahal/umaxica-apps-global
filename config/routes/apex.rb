# typed: false
# frozen_string_literal: true

scope module: :apex, as: :apex do
  constraints host: ENV["APEX_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      post "/csp-violation-report", to: "/csp_violations#create"
      # Edge API endpoint (browser/Rails view)
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API endpoint (browser/SPA)
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show, controller: "health"
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      resource :configuration, only: [:show]
      namespace :configuration do
        # logged in user's email settings.
        resources :emails, only: %i(edit update new create)
      end
      resource :preference, only: [:show]
      # for emergency token operations
      namespace :emergency do
        namespace :app do
          resource :token, only: %i(show update)
        end
      end
    end
  end

  constraints host: ENV["APEX_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      post "/csp-violation-report", to: "/csp_violations#create"
      # Edge API endpoint (browser/Rails view)
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API endpoint (browser/SPA)
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show, controller: "health"
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      resource :configuration, only: [:show]
      namespace :configuration do
        # logged in user's email settings.
        resources :emails, only: %i(edit update new create)
      end
      resource :preference, only: [:show]
      # for emergency token operations
      namespace :emergency do
        namespace :app do
          resource :token, only: %i(show update)
        end
      end
    end
  end

  constraints host: ENV["APEX_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      # Health
      resource :health, only: :show, controller: "health"
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      post "/csp-violation-report", to: "/csp_violations#create"
      # Edge API endpoint (browser/Rails view)
      namespace :web do
        namespace :v0 do
          resource :cookie, only: %i(show update)
          resource :theme, only: %i(show update)
        end
      end
      # Edge API endpoint (browser/SPA)
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show, controller: "health"
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # for emergency
      namespace :emergency do
        namespace :app do
          resource :token, only: %i(show update)
          resource :cache, only: %i(show update destroy)
        end
        namespace :com do
          resource :token, only: %i(show update)
          resource :cache, only: %i(show update destroy)
        end
        namespace :org do
          resource :cache, only: %i(show update destroy)
        end
      end

      resource :configuration, only: [:show]
      namespace :configuration do
        # logged in user's email settings.
        resources :emails, only: %i(edit update new create)
        resources :sessions, only: [] do
          collection do
            post :purge
          end
        end
      end
    end

    constraints host: ENV["APEX_NETWORK_URL"] do
      root to: "roots#index", as: :network_root
      # Health
      resource :health, only: :show, controller: "health"
      # CSP violation reporting
      post "/csp-violation-report", to: "/csp_violations#create"
    end

    constraints host: ENV["APEX_DEVELOPER_URL"] do
      root to: "roots#index", as: :developer_root
      # Health
      resource :health, only: :show, controller: "health"
      # CSP violation reporting
      post "/csp-violation-report", to: "/csp_violations#create"
      # to show the jobs page
      mount MissionControl::Jobs::Engine, at: "/jobs"
      # to show the rails db page
      mount RailsDb::Engine => "/db", :at => "/db"
    end
  end
end
