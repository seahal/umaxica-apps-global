# typed: false
# frozen_string_literal: true

apex_hosts =
  lambda do |env_key, fallback, *local_aliases|
    hosts = [ENV.fetch(env_key, fallback)]
    hosts.concat(local_aliases) unless Rails.env.production?
    hosts.compact.uniq
  end

scope module: :apex, as: :apex do
  constraints host: apex_hosts.call("APEX_CORPORATE_URL", "www.com.localhost", "com.localhost") do
    scope module: :com, as: :com do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
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
      # for account page
      resources :accounts, only: [:index]
      namespace :accounts do
        resource :profile, only: %i(show update)
      end
    end
  end

  constraints host: apex_hosts.call("APEX_SERVICE_URL", "www.app.localhost", "app.localhost") do
    scope module: :app, as: :app do
      root to: "roots#index"
      # Health
      resource :health, only: :show, controller: "health"
      # Robots
      resource :robots, only: :show, path: "robots.txt"
      # Sitemap
      resource :sitemap, only: :show, path: "sitemap.xml"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
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
      # for account page
      resources :accounts, only: [:index]
      namespace :accounts do
        resource :profile, only: %i(show update)
      end
    end
  end

  constraints host: apex_hosts.call("APEX_STAFF_URL", "www.org.localhost", "org.localhost") do
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
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
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
      # for account page
      resources :accounts, only: [:index]
      namespace :accounts do
        resource :profile, only: %i(show update)
      end
    end

    constraints host: ENV["APEX_NETWORK_URL"] do
      root to: "roots#index", as: :network_root
      # Health
      resource :health, only: :show, controller: "health"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
    end

    constraints host: ENV["APEX_DEVELOPER_URL"] do
      root to: "roots#index", as: :developer_root
      # Health
      resource :health, only: :show, controller: "health"
      # CSP violation reporting
      resource :csp_violation_report, only: :create, path: "csp-violation-report"
      # to show the jobs page
      mount MissionControl::Jobs::Engine, at: "/jobs"
      # to show the rails db page
      mount RailsDb::Engine => "/db", :at => "/db"
    end
  end
end
