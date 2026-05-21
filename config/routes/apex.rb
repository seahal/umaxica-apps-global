# typed: false
# frozen_string_literal: true

scope module: :apex, as: :apex do
  constraints host: ENV["APEX_SERVICE_URL"] do
    scope module: :app, as: :app do
      root to: "roots#index"
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
      # Edge API
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :sso do
        resource :authorization, only: :show
        resource :logout, only: :create
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  constraints host: ENV["APEX_CORPORATE_URL"] do
    scope module: :com, as: :com do
      root to: "roots#index"
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
      # Edge API
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :sso do
        resource :authorization, only: :show
        resource :logout, only: :create
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  constraints host: ENV["APEX_STAFF_URL"] do
    scope module: :org, as: :org do
      root to: "roots#index"
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
      # Edge API
      namespace :edge do
        namespace :v0 do
          resource :health, only: :show
          resource :cookie, only: %i(show update)
          resource :dbsc, only: :create
        end
      end
      # OIDC callback
      namespace :auth do
        resource :callback, only: :show
      end
      namespace :sso do
        resource :authorization, only: :show
        resource :logout, only: :create
      end
      # for account page
      resources :accounts, only: [:index]
    end
  end

  constraints host: ENV["APEX_NETWORK_URL"] do
    scope module: :net, as: :network do
      root to: "roots#index", as: :root
      # Health
      resource :health, only: :show
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end
  end

  constraints host: ENV["APEX_DEVELOPER_URL"] do
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
